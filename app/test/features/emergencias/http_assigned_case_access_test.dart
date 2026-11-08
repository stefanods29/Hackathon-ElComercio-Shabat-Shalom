import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';
import 'package:vecinal/features/emergencias/data/http_assigned_case_access.dart';

void main() {
  final caseId = newLocalId();
  final permitId = newLocalId();
  final expiry = DateTime.utc(2026, 11, 9);
  const scope = AssignedCaseScope.exactLocation;

  test('pide permiso auditado con el alcance y devuelve solo la autorización', () async {
    final api = Dio(BaseOptions(validateStatus: (_) => true));
    addTearDown(api.close);
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.method, 'POST');
          expect(request.path, '/v1/pedidos-ayuda/$caseId/accesos-sincronizacion');
          expect(request.data, {'alcance': 'exacta'});
          expect(request.headers[idempotencyKeyHeader], isNotEmpty);
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: 201,
              data: {'autorizacionId': permitId, 'venceEn': expiry.toIso8601String()},
            ),
          );
        },
      ),
    );
    expect(await HttpAssignedCaseAccess(api).open(caseId, scope), (
      authorizationId: permitId,
      expiresAt: expiry,
    ));
  });

  test('una ruta ausente, un rechazo o una respuesta inválida no autorizan', () async {
    final api = Dio(BaseOptions(validateStatus: (_) => true));
    addTearDown(api.close);
    var calls = 0;
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: [404, 403, 200][calls++],
              data: {'autorizacionId': permitId, 'venceEn': 'inválido'},
            ),
          );
        },
      ),
    );
    final access = HttpAssignedCaseAccess(api);
    expect(await access.open(caseId, scope), isNull);
    expect(await access.open(caseId, scope), isNull);
    expect(await access.open(caseId, scope), isNull);
    expect(calls, 3);
  });
}
