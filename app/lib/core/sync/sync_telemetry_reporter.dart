import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:powersync/powersync.dart';
import 'package:vecinal/core/network/classify_response.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/sync_metrics.dart';

/// What the reporter reads from the phone. The real one is [PowerSyncTelemetrySource].
abstract interface class SyncTelemetrySource {
  /// Rows of `envios` that got an answer after [since].
  Future<List<Map<String, Object?>>> submissionsAnsweredAfter(DateTime since);

  /// Actions in the local queue that have not reached the server.
  Future<int> pendingUploads();

  DateTime? get lastSyncedAt;

  /// One event each time the connection with PowerSync starts failing.
  Stream<void> connectionFailures();
}

class PowerSyncTelemetrySource implements SyncTelemetrySource {
  PowerSyncTelemetrySource(this._database);

  final PowerSyncDatabase _database;

  @override
  Future<List<Map<String, Object?>>> submissionsAnsweredAfter(DateTime since) async {
    final rows = await _database.getAll(
      'SELECT estado, creado_en, ultimo_intento_en, motivo_codigo FROM envios '
      'WHERE ultimo_intento_en > ?',
      [since.toUtc().toIso8601String()],
    );
    return [for (final row in rows) Map<String, Object?>.of(row)];
  }

  @override
  Future<int> pendingUploads() async {
    final row = await _database.get('SELECT count(*) AS pending FROM ps_crud');
    return row['pending'] as int;
  }

  @override
  DateTime? get lastSyncedAt => _database.currentStatus.lastSyncedAt;

  @override
  Stream<void> connectionFailures() {
    var failing = false;
    return _database.statusStream.where((status) {
      final now = status.downloadError != null || status.uploadError != null;
      final started = now && !failing;
      failing = now;
      return started;
    });
  }
}

/// Sends the sync counters of the phone at most once a day (Lot A, part 3).
///
/// The body only has the fields of the contract. The report and its `Idempotency-Key` are saved
/// before sending, so a retry after a failure repeats the same report and the server never counts
/// it twice. The first period starts on the first run; nothing is sent before a full day.
class SyncTelemetryReporter {
  SyncTelemetryReporter({
    required this._source,
    required this._api,
    required this._store,
    required String accountId,
    required this._appVersion,
    required this._system,
    this._clock = DateTime.now,
    this.reportEvery = const Duration(days: 1),
  }) : _periodKey = periodStartKey(accountId),
       _pendingKey = pendingReportKey(accountId);

  static const path = '/v1/telemetria/sincronizacion';

  static String periodStartKey(String accountId) => 'telemetry.$accountId.periodStart';

  static String pendingReportKey(String accountId) => 'telemetry.$accountId.pending';

  /// Deletes what the account left in the secure store (sign-out and account deletion).
  static Future<void> discard({required SecureStore store, required String accountId}) async {
    await store.delete(periodStartKey(accountId));
    await store.delete(pendingReportKey(accountId));
  }

  final SyncTelemetrySource _source;
  final Dio _api;
  final SecureStore _store;
  final String _appVersion;

  /// `android` or `ios`; null on other systems, where nothing is reported.
  final String? _system;
  final DateTime Function() _clock;
  final Duration reportEvery;
  final String _periodKey;
  final String _pendingKey;
  StreamSubscription<void>? _failures;
  Future<void>? _running;
  int _connectionErrors = 0;
  bool _closed = false;

  /// Starts counting connection errors and sends a report if one is due.
  Future<void> start() {
    if (_closed || _system == null) return Future.value();
    _failures ??= _source.connectionFailures().listen((_) => _connectionErrors++);
    return maybeReport();
  }

  /// On start and on resume. Concurrent calls share the same attempt.
  Future<void> maybeReport() {
    if (_closed || _system == null) return Future.value();
    return _running ??= _report().whenComplete(() => _running = null);
  }

  Future<void> close() async {
    _closed = true;
    await _failures?.cancel();
    _failures = null;
  }

  Future<void> _report() async {
    final pending = _decode(await _store.read(_pendingKey)) ?? await _closePeriod();
    if (pending == null || _closed) return;
    if (await _send(pending)) {
      await _store.write(_periodKey, pending.periodEnd);
      await _store.delete(_pendingKey);
    }
  }

  /// Saves the report of the period that ends now, or null while the day is not over.
  Future<_PendingReport?> _closePeriod() async {
    final now = _clock().toUtc();
    final start = DateTime.tryParse(await _store.read(_periodKey) ?? '');
    if (start == null || now.isBefore(start)) {
      await _store.write(_periodKey, now.toIso8601String());
      return null;
    }
    if (now.difference(start) < reportEvery) return null;
    final report = buildSyncTelemetryReport(
      submissions: await _source.submissionsAnsweredAfter(start),
      periodStart: start,
      periodEnd: now,
      pendingUploads: await _source.pendingUploads(),
      lastSyncedAt: _source.lastSyncedAt,
      connectionErrors: _connectionErrors,
      appVersion: _appVersion,
      system: _system!,
    );
    final pending = _PendingReport(key: newLocalId(), body: report.toJson());
    await _store.write(_pendingKey, jsonEncode(pending.toJson()));
    // Errors from now on belong to the next report.
    _connectionErrors = 0;
    return pending;
  }

  /// True when the report is done: accepted, or rejected for good (it would never pass).
  Future<bool> _send(_PendingReport pending) async {
    try {
      final response = await _api.post<Object?>(
        path,
        data: pending.body,
        options: Options(headers: {idempotencyKeyHeader: pending.key}),
      );
      // Without a valid session the report waits for the next attempt.
      if (response.statusCode == 401) return false;
      return switch (classifyResponse(response.statusCode, response.data)) {
        Accepted() || Rejected() => true,
        TransientFailure() => false,
      };
    } on DioException {
      return false;
    }
  }

  static _PendingReport? _decode(String? text) {
    if (text == null) return null;
    try {
      final json = jsonDecode(text);
      if (json is! Map<String, Object?>) return null;
      final key = json['clave'];
      final body = json['cuerpo'];
      if (key is! String || body is! Map<String, Object?> || body['periodoFin'] is! String) {
        return null;
      }
      return _PendingReport(key: key, body: body);
    } on FormatException {
      return null;
    }
  }
}

class _PendingReport {
  const _PendingReport({required this.key, required this.body});

  final String key;
  final Map<String, Object?> body;

  String get periodEnd => body['periodoFin']! as String;

  Map<String, Object?> toJson() => {'clave': key, 'cuerpo': body};
}
