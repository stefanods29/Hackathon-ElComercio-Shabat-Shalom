import 'package:dio/dio.dart';
import 'package:vecinal/core/config/app_environment.dart';

/// HTTP client of the `/v1` REST API.
///
/// It never throws because of an HTTP status: every response goes through `classifyResponse`
/// to decide between "sent", "could not complete" or retry. The session provides [getToken].
Dio createApiClient(AppEnvironment environment, {required Future<String?> Function() getToken}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: environment.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      validateStatus: (_) => true,
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        } catch (error, stack) {
          handler.reject(DioException(requestOptions: options, error: error, stackTrace: stack));
        }
      },
    ),
  );
  return dio;
}
