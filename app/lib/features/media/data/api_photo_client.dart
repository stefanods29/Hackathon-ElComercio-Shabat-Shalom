import 'package:dio/dio.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/domain/photo_ports.dart';

class ApiPhotoClient implements PhotoApi {
  ApiPhotoClient({required this.dio, required this.getCredentials});
  final Dio dio;
  final MediaCredentials? Function() getCredentials;
  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    LocalPhoto photo, {
    String? key,
    Map<String, dynamic>? body,
  }) async {
    final credentials = getCredentials();
    if (credentials == null) throw const PhotoFailure('no_autenticado');
    if (photo.ownerId != credentials.userId) {
      throw const PhotoFailure('cuenta_distinta', retryable: false);
    }
    try {
      final response = await dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: {
            'Authorization': 'Bearer ${credentials.accessToken}',
            idempotencyKeyHeader: ?key,
          },
          validateStatus: (_) => true,
        ),
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) return Map<String, dynamic>.from(response.data as Map);
      final data = response.data;
      final code = data is Map && data['codigo'] is String
          ? data['codigo'] as String
          : 'no_se_pudo_completar';
      throw PhotoFailure(
        code,
        retryable:
            status == 401 || status == 408 || status == 409 || status == 429 || status >= 500,
      );
    } on DioException {
      throw const PhotoFailure('sin_conexion');
    }
  }

  @override
  Future<String> reserve(LocalPhoto photo) async {
    await _request(
      'POST',
      '/v1/archivos',
      photo,
      key: photo.reserveKey,
      body: {
        'id': photo.id,
        'tipoContenido': 'image/jpeg',
        'bytes': photo.bytes,
        'sha256': photo.sha256,
      },
    );
    // The idempotent creation response can be old; read the authoritative current state.
    return state(photo);
  }

  @override
  Future<PhotoUploadPermission> permit(LocalPhoto photo) async {
    // A renewed lease is a new action; replaying an expired idempotent response cannot renew it.
    final data = await _request(
      'POST',
      '/v1/archivos/${photo.id}/subida',
      photo,
      key: newLocalId(),
    );
    return PhotoUploadPermission(
      url: Uri.parse(data['url'] as String),
      headers: Map<String, String>.from(data['encabezados'] as Map),
      expiresAt: DateTime.parse(data['venceEn'] as String),
    );
  }

  @override
  Future<void> confirm(LocalPhoto photo) async {
    await _request('POST', '/v1/archivos/${photo.id}/confirmar', photo, key: photo.confirmKey);
  }

  @override
  Future<String> state(LocalPhoto photo) async =>
      (await _request('GET', '/v1/archivos/${photo.id}', photo))['estado'] as String;
  @override
  Future<void> remove(LocalPhoto photo) async {
    await _request('POST', '/v1/archivos/${photo.id}/baja', photo, key: photo.removeKey);
  }
}
