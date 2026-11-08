import 'package:dio/dio.dart';
import 'package:vecinal/core/config/app_environment.dart';

/// Client of the environment's public CDN (`AppEnvironment.cdnBaseUrl`).
///
/// Public files only: unlike `createApiClient` it has no interceptor that adds the session token,
/// it sends no identifier of the neighbor and it returns raw bytes so the caller can check the
/// SHA-256 before trusting them.
Dio createCdnClient(AppEnvironment environment) => Dio(
  BaseOptions(
    baseUrl: environment.cdnBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.bytes,
    validateStatus: (_) => true,
  ),
);
