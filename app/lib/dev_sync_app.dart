import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:vecinal/app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/dev_sync_session.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/powersync_sync_service.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/directorio/data/powersync_service_directory_repository.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';
import 'package:vecinal/features/emergencias/assigned_case_provider.dart';
import 'package:vecinal/features/reputacion/data/powersync_reputation_repository.dart';
import 'package:vecinal/features/reputacion/data/providers.dart';
import 'package:vecinal/features/solidaridad/data/powersync_post_repository.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Hosts the temporary seeded session while the account and OTP screens are being built.
class DevSyncApp extends StatefulWidget {
  const DevSyncApp({
    super.key,
    required this.environment,
    required this.directory,
    required this.store,
  });

  final AppEnvironment environment;
  final String directory;
  final SecureStore store;

  @override
  State<DevSyncApp> createState() => _DevSyncAppState();
}

class _DevSyncAppState extends State<DevSyncApp> {
  static const _signedOutKey = 'vecinal.dev-session.signed-out';
  static const _account = LocalSession.demo;
  late Future<Widget?> _screen;
  late Future<Widget?> Function() _operation;
  Future<void> Function()? _closeSession;
  bool _purging = false;

  String get _wallPath => path.join(widget.directory, 'vecinal-demo.db');
  String get _casePath => path.join(widget.directory, 'vecinal-demo-cases.db');

  @override
  void initState() {
    super.initState();
    _operation = _restore;
    _screen = _operation();
  }

  Future<Widget?> _restore() async {
    if (await widget.store.read(_signedOutKey) == null) return _open();
    // The flag also survives a process exit in the middle of deleting the files.
    await Future.wait([
      LocalSyncDatabase.discard(
        path: _wallPath,
        store: widget.store,
        accountId: _account.neighborId,
      ),
      AssignedCaseCache.discard(
        path: _casePath,
        store: widget.store,
        accountId: _account.neighborId,
      ),
    ]);
    return null;
  }

  void _show(Future<Widget?> Function() operation) {
    if (!mounted) return;
    setState(() {
      _operation = operation;
      _screen = operation();
    });
  }

  void _signIn() => _show(() async {
    await widget.store.delete(_signedOutKey);
    return _open();
  });

  void _signOut(Future<void> Function() wipe) {
    if (_purging) return;
    _show(() async {
      _purging = true;
      try {
        await widget.store.write(_signedOutKey, '1');
        await wipe();
        _closeSession = null;
        return null;
      } finally {
        _purging = false;
      }
    });
  }

  Future<Widget?> _open() async {
    if (!mounted) return null;
    final environment = widget.environment;
    final local = await LocalSyncDatabase.open(
      path: _wallPath,
      store: widget.store,
      accountId: _account.neighborId,
    );
    if (!mounted) {
      await local.close();
      return null;
    }

    final publicApi = createApiClient(environment, getToken: () async => null);
    final session = DevSyncSession(publicApi);
    final api = createApiClient(environment, getToken: session.getToken);
    late final Future<void> Function() wipe;
    final connector = VecinalConnector(
      api,
      endpointOverride: environment.powersyncUrl.isEmpty ? null : environment.powersyncUrl,
      onSessionRevoked: () => Timer.run(() => _signOut(wipe)),
    );
    final sync = PowerSyncSyncService(local, connector);
    final cases = AssignedCaseCache(
      path: _casePath,
      store: widget.store,
      accountId: _account.neighborId,
      connector: connector,
      clock: DateTime.now,
    );
    final lifecycle = AppLifecycleListener(onResume: () => _report(cases.review()));
    var stopped = false;

    Future<void> close({required bool purge}) async {
      final firstClose = !stopped;
      if (firstClose) {
        stopped = true;
        lifecycle.dispose();
        session.close();
        connector.stopRefreshing();
      }
      try {
        await Future.wait([
          if (purge) ...[
            sync.disconnectAndWipeLocalData(),
            cases.wipeForSignOut(),
          ] else ...[
            local.close(),
            cases.close(),
          ],
        ]);
        if (purge) await cases.close();
      } finally {
        if (firstClose) {
          connector.invalidateCredentials();
          publicApi.close(force: true);
          api.close(force: true);
        }
      }
    }

    wipe = () => close(purge: true);
    _closeSession = () => close(purge: false);
    try {
      await sync.connect();
      await cases.restore();
    } catch (_) {
      if (!_purging && mounted) {
        _closeSession = null;
        await close(purge: false);
      }
      rethrow;
    }
    return ProviderScope(
      overrides: [
        demoSignOutProvider.overrideWithValue(() => _signOut(wipe)),
        syncServiceProvider.overrideWithValue(sync),
        syncedPostRepositoryProvider.overrideWithValue(
          PowerSyncPostRepository(
            local.database,
            neighborId: _account.neighborId,
            zoneId: _account.zoneId,
          ),
        ),
        syncedServiceDirectoryRepositoryProvider.overrideWithValue(
          PowerSyncServiceDirectoryRepository(
            local.database,
            neighborId: _account.neighborId,
            zoneId: _account.zoneId,
          ),
        ),
        syncedReputationRepositoryProvider.overrideWithValue(
          PowerSyncReputationRepository(
            local.database,
            neighborId: _account.neighborId,
            zoneId: _account.zoneId,
          ),
        ),
        assignedCaseCacheProvider.overrideWithValue(cases),
      ],
      child: const VecinalApp(),
    );
  }

  @override
  void dispose() {
    final close = _closeSession;
    if (!_purging && close != null) _report(close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget?>(
    future: _screen,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
        return snapshot.data!;
      }
      return MaterialApp(
        theme: AccessibleTheme.light(),
        darkTheme: AccessibleTheme.dark(),
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            final texts = AppLocalizations.of(context);
            return Scaffold(
              appBar: AppBar(title: Text(texts.appName)),
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: switch (snapshot.connectionState) {
                    ConnectionState.done => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(snapshot.hasError ? texts.demoSessionError : texts.demoWelcome),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: snapshot.hasError ? () => _show(_operation) : _signIn,
                          child: Text(snapshot.hasError ? texts.retryAction : texts.demoSignIn),
                        ),
                      ],
                    ),
                    _ => const CircularProgressIndicator(),
                  },
                ),
              ),
            );
          },
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
