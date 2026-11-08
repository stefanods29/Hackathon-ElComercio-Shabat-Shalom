import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/powersync_sync_service.dart';
import 'package:vecinal/core/sync/sync_telemetry_reporter.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/directorio/data/powersync_service_directory_repository.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';
import 'package:vecinal/features/reputacion/data/powersync_reputation_repository.dart';
import 'package:vecinal/features/solidaridad/data/powersync_post_repository.dart';

/// Resources are scoped to a single account, including the wall and sensitive cache.
class AuthenticatedSyncSession {
  AuthenticatedSyncSession._(
    this.user,
    this.local,
    this.api,
    this.connector,
    this.sync,
    this.cases,
    this.posts,
    this.directory,
    this.reputation,
    this.telemetry,
  ) {
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _report(cases.review());
        _report(telemetry.maybeReport());
      },
    );
  }

  final LocalUser user;
  final LocalSyncDatabase local;
  final Dio api;
  final VecinalConnector connector;
  final PowerSyncSyncService sync;
  final AssignedCaseCache cases;
  final PowerSyncPostRepository posts;
  final PowerSyncServiceDirectoryRepository directory;
  final PowerSyncReputationRepository reputation;

  /// Daily anonymous counters of the sync health (Lot A, part 3).
  final SyncTelemetryReporter telemetry;
  late final AppLifecycleListener _lifecycle;
  Future<void>? _closing;

  static String _wallPath(String directory, String id) => path.join(directory, 'wall-$id.db');
  static String _casePath(String directory, String id) => path.join(directory, 'cases-$id.db');

  static void _validateAccount(String id) {
    if (!Uuid.isValidUUID(fromString: id)) throw const FormatException('Cuenta inválida.');
  }

  static Future<AuthenticatedSyncSession> open({
    required LocalUser user,
    required String directory,
    required SecureStore store,
    required AppEnvironment environment,
    required Future<String?> Function() getToken,
    required void Function() onSessionRevoked,
  }) async {
    _validateAccount(user.neighborId);
    final local = await LocalSyncDatabase.open(
      path: _wallPath(directory, user.neighborId),
      store: store,
      accountId: user.neighborId,
    );
    final api = createApiClient(environment, getToken: getToken);
    final connector = VecinalConnector(
      api,
      endpointOverride: environment.powersyncUrl.isEmpty ? null : environment.powersyncUrl,
      onSessionRevoked: onSessionRevoked,
    );
    final cases = AssignedCaseCache(
      path: _casePath(directory, user.neighborId),
      store: store,
      accountId: user.neighborId,
      connector: connector,
      clock: DateTime.now,
    );
    try {
      return AuthenticatedSyncSession._(
        user,
        local,
        api,
        connector,
        PowerSyncSyncService(local, connector),
        cases,
        PowerSyncPostRepository(local.database, neighborId: user.neighborId, zoneId: user.zoneId!),
        PowerSyncServiceDirectoryRepository(
          local.database,
          neighborId: user.neighborId,
          zoneId: user.zoneId!,
        ),
        PowerSyncReputationRepository(
          local.database,
          neighborId: user.neighborId,
          zoneId: user.zoneId!,
        ),
        SyncTelemetryReporter(
          source: PowerSyncTelemetrySource(local.database),
          api: api,
          store: store,
          accountId: user.neighborId,
          appVersion: environment.appVersion,
          system: Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : null),
        ),
      );
    } catch (_) {
      await local.close();
      await cases.close();
      api.close(force: true);
      rethrow;
    }
  }

  void start() {
    if (_closing == null) _report(_start());
  }

  Future<void> _start() async {
    await cases.restore();
    if (_closing == null) await sync.connect();
    if (_closing == null) _report(telemetry.start());
  }

  Future<void> close({required bool purge}) => _closing ??= _close(purge);

  Future<void> _close(bool purge) async {
    _lifecycle.dispose();
    await telemetry.close();
    connector.stopRefreshing();
    try {
      await Future.wait([
        purge ? sync.disconnectAndWipeLocalData() : local.close(),
        purge ? cases.wipeForSignOut() : cases.close(),
      ]);
      if (purge) await cases.close();
    } finally {
      connector.invalidateCredentials();
      api.close(force: true);
    }
  }

  static Future<void> discard({
    required String directory,
    required SecureStore store,
    required String accountId,
  }) async {
    _validateAccount(accountId);
    await Future.wait([
      LocalSyncDatabase.discard(
        path: _wallPath(directory, accountId),
        store: store,
        accountId: accountId,
      ),
      AssignedCaseCache.discard(
        path: _casePath(directory, accountId),
        store: store,
        accountId: accountId,
      ),
      SyncTelemetryReporter.discard(store: store, accountId: accountId),
    ]);
  }

  static void _report(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stack) {
        FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
      }),
    );
  }
}
