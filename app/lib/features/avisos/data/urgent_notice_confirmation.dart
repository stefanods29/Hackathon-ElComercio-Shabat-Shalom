import 'package:dio/dio.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/features/avisos/domain/push_registration.dart';

/// Confirms an opened urgent notice (`POST /v1/avisos-urgentes/{id}/confirmar`), which stops its
/// SMS backup. Best effort: without a connection the SMS may still arrive, and that is what the
/// backup is for. Confirming twice is harmless, so each attempt has its own key.
Future<void> confirmUrgentNotice(Dio dio, PushCredentials credentials, String noticeId) async {
  final token = await credentials.accessToken();
  if (token == null) return;
  await dio.post<Object?>(
    '/v1/avisos-urgentes/$noticeId/confirmar',
    options: Options(
      headers: {'Authorization': 'Bearer $token', idempotencyKeyHeader: newLocalId()},
      validateStatus: (_) => true,
    ),
  );
}
