import 'package:dio/dio.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/sign_in.dart';

/// Tokens of an open session. They live only in memory (design, section 2).
class SessionTokens {
  const SessionTokens({
    required this.accessToken,
    required this.expiresAt,
    required this.refreshToken,
    required this.refreshExpiresAt,
    required this.user,
  });

  /// Reads `SesionRenovable` from the contract. Roles the console does not know are ignored.
  factory SessionTokens.fromJson(Object? data) {
    if (data is! Map) throw const UnexpectedResponse('Sesión inválida.');
    final json = Map<String, Object?>.from(data);
    final user = json['usuario'];
    final access = json['tokenDeAcceso'];
    final refresh = json['refreshToken'];
    final expiresAt = DateTime.tryParse('${json['expiraEn']}');
    final refreshExpiresAt = DateTime.tryParse('${json['refreshExpiraEn']}');
    if (user is! Map ||
        access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        expiresAt == null ||
        refreshExpiresAt == null) {
      throw const UnexpectedResponse('Sesión inválida.');
    }
    final id = user['id'];
    final name = user['nombreVisible'];
    final zone = user['zonaId'];
    final roles = user['roles'];
    if (id is! String || name is! String) throw const UnexpectedResponse('Usuario inválido.');
    return SessionTokens(
      accessToken: access,
      expiresAt: expiresAt,
      refreshToken: refresh,
      refreshExpiresAt: refreshExpiresAt,
      user: Operator(
        id: id,
        displayName: name,
        zoneId: zone is String ? zone : null,
        roles: {
          if (roles is List)
            for (final code in roles)
              if (code is String) ?OperationalRole.fromCode(code),
        },
      ),
    );
  }

  final String accessToken;
  final DateTime expiresAt;
  final String refreshToken;
  final DateTime refreshExpiresAt;
  final Operator user;
}

/// Session routes of `/v1/auth`, the same ones the app uses. Each call that needs a bearer token
/// passes its own, so this client has no token interceptor.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<CodeRequest> requestCode(String phone) async {
    final response = await _call(() => _dio.post<Object?>('/v1/auth/otp', data: {'telefono': phone}));
    _require(response, 202);
    final body = response.data;
    if (body is! Map) throw const UnexpectedResponse('Respuesta del código inválida.');
    return CodeRequest(
      retryAfterSeconds: (body['reintentarEnSegundos'] as num?)?.ceil() ?? 60,
      expiresInSeconds: (body['expiraEnSegundos'] as num?)?.ceil() ?? 300,
    );
  }

  Future<SessionTokens> verifyCode(String phone, String code) async {
    final response = await _call(
      () => _dio.post<Object?>('/v1/auth/otp/verificar', data: {'telefono': phone, 'codigo': code}),
    );
    if (response.statusCode == 401) throw const SignInFailure(SignInProblem.invalidCode);
    _require(response, 200);
    return SessionTokens.fromJson(response.data);
  }

  /// With `PHONE_AUTH=firebase`: the API exchanges the Firebase ID token for its own session.
  Future<SessionTokens> exchangeFirebaseToken(String token) async {
    final response = await _call(
      () => _dio.post<Object?>('/v1/auth/firebase', data: {'tokenFirebase': token}),
    );
    if (response.statusCode == 401) throw const SignInFailure(SignInProblem.checkFailed);
    _require(response, 200);
    return SessionTokens.fromJson(response.data);
  }

  /// Null when the API no longer accepts the refresh token.
  Future<SessionTokens?> refresh(String refreshToken) async {
    final response = await _call(
      () => _dio.post<Object?>('/v1/auth/refrescar', data: {'refreshToken': refreshToken}),
    );
    if (response.statusCode == 401) return null;
    if (response.statusCode != 200) throw ConnectionProblem('refresh ${response.statusCode}');
    return SessionTokens.fromJson(response.data);
  }

  /// Best effort: the console forgets the session anyway.
  Future<void> signOut(String accessToken) async {
    try {
      await _dio.post<Object?>(
        '/v1/auth/cerrar-sesion',
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );
    } on DioException {
      // Offline: the access token expires on its own and the refresh token was only in memory.
    }
  }

  static Future<Response<Object?>> _call(Future<Response<Object?>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      final failed = error.response;
      if (failed == null) throw const SignInFailure(SignInProblem.network);
      return failed;
    }
  }

  static void _require(Response<Object?> response, int expected) {
    final status = response.statusCode;
    if (status == expected) return;
    if (status == 429) {
      final body = response.data;
      final seconds = body is Map ? body['reintentarEnSegundos'] : null;
      throw SignInFailure(
        SignInProblem.tooManyAttempts,
        retryAfterSeconds: seconds is num
            ? seconds.ceil()
            : int.tryParse(response.headers.value('retry-after') ?? '') ?? 60,
      );
    }
    if (status == 400 || status == 422) throw const SignInFailure(SignInProblem.invalidPhone);
    throw const SignInFailure(SignInProblem.sendFailed);
  }
}
