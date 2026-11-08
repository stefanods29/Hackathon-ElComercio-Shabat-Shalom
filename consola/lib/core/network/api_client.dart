import 'package:dio/dio.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/network/problem_details.dart';

/// HTTP client of the `/v1` API. It never throws because of an HTTP status: [ConsoleApi] decides.
///
/// [getToken] adds the bearer token; the session's own client has none, so refreshing never
/// waits on itself. The browser sends no cookies (`withCredentials` stays off).
Dio createApiClient(ConsoleEnvironment environment, {Future<String?> Function()? getToken}) {
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
  if (getToken != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            final token = await getToken();
            if (token != null) options.headers['Authorization'] = 'Bearer $token';
            handler.next(options);
          } catch (error, stack) {
            handler.reject(DioException(requestOptions: options, error: error, stackTrace: stack));
          }
        },
      ),
    );
  }
  return dio;
}

/// JSON over the `/v1` API with Problem Details errors. Every call goes online: nothing is cached
/// in the browser (the API answers `Cache-Control: no-store` on the console's routes).
class ConsoleApi {
  ConsoleApi(this._dio, {required this._onUnauthorized});

  final Dio _dio;
  final void Function() _onUnauthorized;

  Future<Map<String, Object?>> getJson(String path, {Map<String, Object?>? query}) =>
      _send(() => _dio.get<Object?>(path, queryParameters: query), const {200});

  /// Every change carries an `Idempotency-Key`: retrying the same attempt never applies it twice.
  Future<Map<String, Object?>> postJson(
    String path, {
    Object? body,
    required String idempotencyKey,
    Set<int> expected = const {200, 201},
  }) => _send(
    () => _dio.post<Object?>(path, data: body, options: _withKey(idempotencyKey)),
    expected,
  );

  Future<Map<String, Object?>> putJson(
    String path, {
    required Object body,
    required String idempotencyKey,
    Set<int> expected = const {200, 201},
  }) =>
      _send(() => _dio.put<Object?>(path, data: body, options: _withKey(idempotencyKey)), expected);

  static Options _withKey(String key) => Options(headers: {idempotencyKeyHeader: key});

  Future<Map<String, Object?>> _send(
    Future<Response<Object?>> Function() request,
    Set<int> expected,
  ) async {
    final response = await _attempt(request);
    final status = response.statusCode ?? 0;
    if (expected.contains(status)) return _object(response.data);
    if (status == 401) _onUnauthorized();
    throw ApiProblem(
      ProblemDetails.fromResponse(
        status,
        response.data,
        retryAfterHeader: response.headers.value('retry-after'),
      ),
    );
  }

  static Future<Response<Object?>> _attempt(Future<Response<Object?>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final failed = error.response;
      if (failed == null) throw ConnectionProblem(error.type.name);
      return failed;
    }
  }

  static Map<String, Object?> _object(Object? data) {
    if (data is Map) return Map<String, Object?>.from(data);
    if (data == null || (data is String && data.isEmpty)) return const {};
    throw const UnexpectedResponse('Se esperaba un objeto JSON.');
  }
}

/// Reads a required field of a JSON object, or explains that the contract was not followed.
T field<T>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw UnexpectedResponse('Falta o es inválido el campo "$key".');
}

/// Reads a required list of JSON objects.
List<Map<String, Object?>> objects(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw UnexpectedResponse('Falta la lista "$key".');
  return [
    for (final row in value)
      if (row is Map)
        Map<String, Object?>.from(row)
      else
        throw UnexpectedResponse('"$key" inválido.'),
  ];
}

/// Reads an ISO 8601 instant.
DateTime instant(Map<String, Object?> json, String key) {
  final value = json[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw UnexpectedResponse('Fecha inválida en "$key".');
  return parsed;
}

/// Reads an optional ISO 8601 instant.
DateTime? optionalInstant(Map<String, Object?> json, String key) =>
    json[key] == null ? null : instant(json, key);
