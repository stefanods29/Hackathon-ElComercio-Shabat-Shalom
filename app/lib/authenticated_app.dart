import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/authenticated_sync_session.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/features/avisos/domain/push_registration.dart';
import 'package:vecinal/features/cuenta/data/firebase_phone_verifier.dart';
import 'package:vecinal/features/cuenta/data/http_auth_repository.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/emergencias/assigned_case_provider.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Production entry point. The development seed remains available through DEV_SYNC.
class AuthenticatedApp extends StatefulWidget {
  const AuthenticatedApp({
    super.key,
    required this.environment,
    required this.directory,
    required this.store,
  });
  final AppEnvironment environment;
  final String directory;
  final SecureStore store;

  @override
  State<AuthenticatedApp> createState() => _AuthenticatedAppState();
}

class _AuthenticatedAppState extends State<AuthenticatedApp> {
  late final Dio _publicApi;
  late final HttpAuthRepository _auth;
  late Future<void> _ready;
  AuthenticatedSyncSession? _session;

  @override
  void initState() {
    super.initState();
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
  }

  Future<void> _purge(String accountId) async {
    final session = _session;
    if (session != null) await session.close(purge: true);
    await AuthenticatedSyncSession.discard(
      directory: widget.directory,
      store: widget.store,
      accountId: accountId,
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
    _report(() async {
      await _auth.close();
      await _session?.close(purge: false);
      _publicApi.close(force: true);
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
          key: ValueKey(session?.user.neighborId ?? 'signed-out'),
          overrides: [
            authRepositoryProvider.overrideWithValue(_auth),
            if (session != null) ...[
              sessionProvider.overrideWithValue(
                LocalSession(
                  neighborId: session.user.neighborId,
                  zoneId: session.user.zoneId!,
                  displayName: session.user.displayName,
                ),
              ),
              syncServiceProvider.overrideWithValue(session.sync),
              syncedPostRepositoryProvider.overrideWithValue(session.posts),
              assignedCaseCacheProvider.overrideWithValue(session.cases),
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
