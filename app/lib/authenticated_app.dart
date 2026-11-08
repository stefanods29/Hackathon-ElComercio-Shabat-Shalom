import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:vecinal/app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/network/cdn_client.dart';
import 'package:vecinal/core/storage/account_data_purge.dart';
import 'package:vecinal/core/storage/pending_photo_purger.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/authenticated_sync_session.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/features/avisos/domain/push_registration.dart';
import 'package:vecinal/features/cuenta/data/firebase_phone_verifier.dart';
import 'package:vecinal/features/cuenta/data/http_auth_repository.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/emergencias/assigned_case_provider.dart';
import 'package:vecinal/features/emergencias/data/emergency_directory_repository.dart';
import 'package:vecinal/features/emergencias/data/emergency_directory_store.dart';
import 'package:vecinal/features/emergencias/data/providers.dart';
import 'package:vecinal/features/reputacion/data/providers.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Production entry point. The development seed remains available through DEV_SYNC.
class AuthenticatedApp extends StatefulWidget {
  const AuthenticatedApp({
    super.key,
    required this.environment,
    required this.directory,
    required this.store,
    this.pendingPhotos = const NoPendingPhotos(),
  });
  final AppEnvironment environment;
  final String directory;
  final SecureStore store;

  /// Review photos not uploaded yet; Lot C (part 2) passes its queue.
  final PendingPhotoPurger pendingPhotos;

  @override
  State<AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<AuthenticatedApp> {
  late final Dio _publicApi;
  late final HttpAuthRepository _auth;
  late final Dio _cdn;
  late final EmergencyDirectoryRepository _emergency;
  late final AppLifecycleListener _lifecycle;
  late Future<void> _ready;
  AuthenticatedSyncSession? _session;

  @override
  void initState() {
    super.initState();
    // Public copy outside the account database: it opens without a session and survives sign-out.
    // Created before the session restore, which may need to purge an interrupted sign-out.
    _cdn = createCdnClient(widget.environment);
    _emergency = EmergencyDirectoryRepository(
      cdn: _cdn,
      store: FileEmergencyDirectoryStore(path.join(widget.directory, 'emergencia')),
      loadBackup: loadEmergencyBackup,
    );
    _lifecycle = AppLifecycleListener(onResume: _refreshEmergencyDirectory);
    _publicApi = createApiClient(widget.environment, getToken: () async => null);
    _auth = HttpAuthRepository(
      api: _publicApi,
      store: widget.store,
      activate: _activate,
      purge: _purge,
      phoneVerifier: widget.environment.phoneAuthWithFirebase ? FirebasePhoneVerifier() : null,
    );
    _ready = _auth.initialize();
  }

  Future<void> _activate(LocalUser user) async {
    final current = _session;
    if (current?.user.neighborId == user.neighborId && current?.user.zoneId == user.zoneId) return;
    if (current != null) await current.close(purge: true);
    final session = await AuthenticatedSyncSession.open(
      user: user,
      directory: widget.directory,
      store: widget.store,
      environment: widget.environment,
      getToken: _auth.getToken,
      onSessionRevoked: () => _report(_auth.revokeSession()),
    );
    if (!mounted) {
      await session.close(purge: false);
      return;
    }
    setState(() => _session = session);
    // Login/restore must finish before PowerSync requests a token from the same queue.
    Timer.run(session.start);
    _refreshEmergencyDirectory();
  }

  /// On sign-in and on resume; the repository checks the CDN at most once a day per zone.
  void _refreshEmergencyDirectory() {
    final zoneId = _session?.user.zoneId;
    // `then` keeps a Future<void>, so the error handler of `_report` may return null.
    if (zoneId != null) _report(_emergency.refresh(zoneId: zoneId).then((_) {}));
  }

  /// Sign-out, revoked session and account deletion (Lot A, part 4).
  Future<void> _purge(String accountId) async {
    await purgeAccountData(
      accountId,
      pendingPhotos: widget.pendingPhotos,
      closeSession: () async {
        final session = _session;
        if (session != null) await session.close(purge: true);
      },
      discardStorage: (id) async {
        await AuthenticatedSyncSession.discard(
          directory: widget.directory,
          store: widget.store,
          accountId: id,
        );
        // The public emergency directory stays; only the zone of its last check goes.
        await _emergency.forgetLastCheck();
      },
    );
    if (mounted) setState(() => _session = null);
  }

  /// The push journal belongs to one neighbor: it never sends with another neighbor's JWT.
  Future<String?> _tokenFor(String neighborId) async {
    if (_session?.user.neighborId != neighborId) return null;
    return _auth.getToken();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _report(() async {
      await _auth.close();
      await _session?.close(purge: false);
      await _emergency.close();
      _publicApi.close(force: true);
      _cdn.close(force: true);
    }());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
        final session = _session;
        return ProviderScope(
          // A new zone gets a fresh scope: no provider keeps rows of the previous zone.
          key: ValueKey(
            session == null ? 'signed-out' : '${session.user.neighborId}:${session.user.zoneId}',
          ),
          overrides: [
            authRepositoryProvider.overrideWithValue(_auth),
            emergencyDirectoryRepositoryProvider.overrideWithValue(_emergency),
            if (session != null) ...[
              sessionProvider.overrideWithValue(
                LocalSession(
                  neighborId: session.user.neighborId,
                  zoneId: session.user.zoneId!,
                  displayName: session.user.displayName,
                  trustLevel: session.user.trustLevel,
                ),
              ),
              syncServiceProvider.overrideWithValue(session.sync),
              syncedPostRepositoryProvider.overrideWithValue(session.posts),
              syncedServiceDirectoryRepositoryProvider.overrideWithValue(session.directory),
              syncedReputationRepositoryProvider.overrideWithValue(session.reputation),
              assignedCaseCacheProvider.overrideWithValue(session.cases),
              ownHelpRequestRepositoryProvider.overrideWithValue(session.helpRequests),
              pushCredentialsProvider.overrideWithValue(
                PushCredentials(
                  userId: session.user.neighborId,
                  zoneId: session.user.zoneId,
                  accessToken: () => _tokenFor(session.user.neighborId),
                ),
              ),
            ],
          ],
          child: const VecinalApp(),
        );
      }
      return MaterialApp(
        theme: AccessibleTheme.light(),
        darkTheme: AccessibleTheme.dark(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: snapshot.hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('No se pudo abrir la sesión guardada.'),
                      FilledButton(
                        onPressed: () => setState(() => _ready = _auth.initialize()),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    },
  );

  void _report(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stack) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
      }),
    );
  }
}
