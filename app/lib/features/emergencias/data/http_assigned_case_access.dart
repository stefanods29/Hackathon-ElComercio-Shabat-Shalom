import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';

/// Provisional contract for B's audited authorization. A missing route cannot grant a stream.
class HttpAssignedCaseAccess {
  const HttpAssignedCaseAccess(this._api);
  final Dio _api;

  Future<AssignedCasePermit?> open(String caseId, AssignedCaseScope scope) async {
    if (!Uuid.isValidUUID(fromString: caseId)) return null;
    try {
      final response = await _api.post<Object?>(
        '/v1/pedidos-ayuda/$caseId/accesos-sincronizacion',
        data: {'alcance': scope.apiValue},
        options: Options(headers: {idempotencyKeyHeader: newLocalId()}),
      );
      final body = response.data;
      if ((response.statusCode != 200 && response.statusCode != 201) ||
          body is! Map<String, Object?>) {
        return null;
      }
      final id = body['autorizacionId'];
      final expiresAt = body['venceEn'];
      if (id is! String || !Uuid.isValidUUID(fromString: id) || expiresAt is! String) {
        return null;
      }
      final expiry = DateTime.tryParse(expiresAt);
      return expiry == null ? null : (authorizationId: id, expiresAt: expiry);
    } on DioException {
      return null;
    }
  }
}
