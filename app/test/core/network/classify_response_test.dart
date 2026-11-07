import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/network/classify_response.dart';
import 'package:vecinal/core/submissions/submission_status.dart';

void main() {
  test('2xx es aceptado, incluido el 200 de un reintento', () {
    expect(classifyResponse(201, null), isA<Accepted>());
    expect(classifyResponse(200, {'id': 'x'}), isA<Accepted>());
  });

  test('un 409 con Problem Details es un rechazo definitivo con su motivo', () {
    final result = classifyResponse(409, <String, Object?>{
      'type': '/problemas/favor-no-disponible',
      'title': 'Conflicto',
      'status': 409,
      'detail': 'Otro vecino ya tomó este favor.',
      'codigo': 'favor_no_disponible',
    });
    expect(result, isA<Rejected>());
    final reason = (result as Rejected).reason;
    expect(reason.code, 'favor_no_disponible');
    expect(reason.detail, 'Otro vecino ya tomó este favor.');
  });

  test('408, 429 y 5xx se reintentan', () {
    for (final status in [408, 429, 500, 502, 503]) {
      expect(classifyResponse(status, null), isA<TransientFailure>(), reason: '$status');
    }
  });

  test('sin respuesta del servidor (sin señal) se reintenta', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/v1/publicaciones'),
      type: DioExceptionType.connectionError,
    );
    expect(classifyError(error), isA<TransientFailure>());
  });

  test('un 4xx sin cuerpo JSON sigue siendo un rechazo definitivo', () {
    final result = classifyResponse(403, 'texto plano');
    expect(result, isA<Rejected>());
    expect((result as Rejected).reason.code, 'desconocido');
  });
}
