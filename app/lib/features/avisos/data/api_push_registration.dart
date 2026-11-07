import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/avisos/domain/push_registration.dart';

class PushRegistrationException implements Exception {
  const PushRegistrationException();
}

/// Durable, owner-scoped journal. A retry keeps its original Idempotency-Key.
/// Credentials are captured for the owner; a session change cannot send with another user's JWT.
class ApiPushRegistration implements PushRegistration {
  ApiPushRegistration({required this.dio, required this.store, required this.credentials});
  final Dio dio;
  final SecureStore store;
  PushCredentials credentials;
  Future<void> _tail = Future.value();
  String get _storageKey => 'push.pending.${credentials.userId}';

  Future<bool> _serialized(Future<bool> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<bool> register(String token, String platform) => _enqueue('alta', token, platform);
  @override
  Future<bool> unregister(String token) => _enqueue('baja', token, null);

  Future<List<Map<String, dynamic>>> _read() async {
    final saved = await store.read(_storageKey);
    if (saved == null) return [];
    return (jsonDecode(saved) as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _save(List<Map<String, dynamic>> items) =>
      items.isEmpty ? store.delete(_storageKey) : store.write(_storageKey, jsonEncode(items));

  Future<bool> _enqueue(String action, String token, String? platform) => _serialized(() async {
    final items = await _read();
    if (!items.any((item) => item['accion'] == action && item['token'] == token)) {
      items.add({'clave': newLocalId(), 'accion': action, 'token': token, 'plataforma': ?platform});
      await _save(items);
    }
    return _flush(items);
  });

  @override
  Future<bool> retry() => _serialized(() async => _flush(await _read()));

  Future<bool> _flush(List<Map<String, dynamic>> items) async {
    while (items.isNotEmpty) {
      final item = items.first;
      Response<dynamic> response;
      try {
        response = await dio.post<dynamic>(
          item['accion'] == 'alta' ? '/v1/dispositivos' : '/v1/dispositivos/baja',
          data: {
            'token': item['token'],
            if (item['accion'] == 'alta') 'plataforma': item['plataforma'],
          },
          options: Options(
            headers: {
              idempotencyKeyHeader: item['clave'],
              'Authorization': 'Bearer ${credentials.accessToken}',
            },
            validateStatus: (_) => true,
          ),
        );
      } on DioException {
        return false;
      }
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        items.removeAt(0);
        await _save(items);
      } else if (status == 401 ||
          status == 408 ||
          status == 409 ||
          status == 429 ||
          status >= 500 ||
          status == 0) {
        return false;
      } else {
        items.removeAt(0);
        await _save(items);
        throw const PushRegistrationException();
      }
    }
    return true;
  }
}
