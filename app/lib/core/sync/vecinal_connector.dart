import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:powersync/powersync.dart';
import 'package:vecinal/core/network/classify_response.dart';
import 'package:vecinal/core/network/problem_details.dart';
import 'package:vecinal/core/submissions/retry_policy.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/command_routes.dart';
import 'package:vecinal/core/sync/submission_row.dart';

class SyncCredentialsFailure implements Exception {
  const SyncCredentialsFailure(this.status, this.code);

  final int? status;
  final String? code;

  bool get sessionRevoked => status == 401 && code == 'sesion_revocada';

  @override
  String toString() => 'Error al obtener credenciales de sincronización ($status).';
}

class VecinalConnector extends PowerSyncBackendConnector {
  VecinalConnector(
    this._api, {
    this.endpointOverride,
    this.onSessionRevoked,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Dio _api;
  final String? endpointOverride;
  final void Function()? onSessionRevoked;
  final DateTime Function() _clock;
  final _random = Random();
  Timer? _refresh;
  bool _refreshEnabled = false;

  void startRefreshing() => _refreshEnabled = true;

  void stopRefreshing() {
    _refreshEnabled = false;
    _refresh?.cancel();
  }

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    final response = await _api.get<Object?>('/v1/sync/credenciales');
    final data = response.data;
    if (response.statusCode != 200) {
      final problem = data is Map<String, Object?>
          ? ProblemDetails.fromJson(data, httpStatus: response.statusCode ?? 0)
          : null;
      final failure = SyncCredentialsFailure(response.statusCode, problem?.code);
      if (failure.sessionRevoked) onSessionRevoked?.call();
      throw failure;
    }
    if (data is! Map<String, Object?> ||
        data['token'] is! String ||
        data['endpoint'] is! String ||
        data['expiraEn'] is! String) {
      throw const FormatException('Credenciales de sincronización inválidas.');
    }
    final endpoint = endpointOverride ?? data['endpoint'] as String;
    final uri = Uri.tryParse(endpoint);
    final expiry = DateTime.tryParse(data['expiraEn'] as String);
    final token = data['token'] as String;
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        expiry == null ||
        !expiry.isAfter(_clock()) ||
        token.isEmpty) {
      throw const FormatException('Credenciales de sincronización inválidas.');
    }
    if (_refreshEnabled) {
      _refresh?.cancel();
      final remaining = expiry.difference(_clock());
      const lead = Duration(minutes: 2);
      final delay = remaining > lead ? remaining - lead : remaining ~/ 2;
      _refresh = Timer(delay, () async {
        try {
          await prefetchCredentials();
        } catch (_) {
          // Keep the cached token. The SDK also retries near expiration or on reconnect.
        }
      });
    }
    return PowerSyncCredentials(endpoint: endpoint, token: token, expiresAt: expiry);
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    final transaction = await database.getNextCrudTransaction();
    if (transaction == null) return;
    for (final command in transaction.crud) {
      if (command.table != 'comandos' || command.op != UpdateType.put) {
        throw StateError('Operación inesperada en la cola de comandos.');
      }
      await _sendCommand(database, command);
    }
    await transaction.complete();
  }

  Future<void> _sendCommand(PowerSyncDatabase database, CrudEntry command) async {
    final row = await database.get('SELECT * FROM envios WHERE id = ?', [command.id]);
    final submission = submissionFromRow(row);
    // A crash after persisting the answer and before complete() must not repeat a final action.
    if (submission.status.isFinal) return;
    final retryAt = row['reintentar_en'] as String?;
    if (retryAt != null && _clock().isBefore(DateTime.parse(retryAt))) {
      throw StateError('El comando está esperando su próximo reintento.');
    }
    final payload = command.opData!;
    final route = commandRoute(submission.kind, submission.resourceId);
    final AttemptResult result;
    try {
      final response = await _api.request<Object?>(
        route.path,
        data: route.sendsBody ? payload['cuerpo'] as String? : null,
        options: Options(
          method: route.method,
          headers: {'Idempotency-Key': submission.idempotencyKey},
        ),
      );
      // An expired access token can be renewed. Keep the command and its key.
      result = response.statusCode == 401
          ? const TransientFailure('Se necesita una sesión vigente para enviar el comando.')
          : classifyResponse(response.statusCode, response.data);
    } on DioException catch (error) {
      await _recordResult(database, submission, classifyError(error));
      rethrow;
    }
    await _recordResult(database, submission, result);
    if (result is TransientFailure) throw StateError(result.description);
  }

  Future<void> _recordResult(
    PowerSyncDatabase database,
    Submission submission,
    AttemptResult result,
  ) async {
    final now = _clock().toUtc();
    final update = submission.recordAttempt(result, now);
    final reason = update.rejectionReason;
    final retryAt = result is TransientFailure
        ? now.add(const RetryPolicy().delayFor(update.attempts, _random)).toIso8601String()
        : null;
    // Keep the downloaded row intact. A definitive answer removes the local overlay atomically.
    await database.execute(
      '''
      UPDATE envios
      SET estado = ?, intentos = ?, ultimo_intento_en = ?, reintentar_en = ?,
          motivo_codigo = ?, motivo_titulo = ?, motivo_detalle = ?,
          publicacion_optimista = CASE WHEN ? THEN NULL ELSE publicacion_optimista END,
          optimista = CASE WHEN ? THEN NULL ELSE optimista END
      WHERE id = ?
      ''',
      [
        update.status.name,
        update.attempts,
        now.toIso8601String(),
        retryAt,
        reason?.code,
        reason?.title,
        reason?.detail,
        update.status.isFinal ? 1 : 0,
        update.status.isFinal ? 1 : 0,
        submission.id,
      ],
    );
  }
}
