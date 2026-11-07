import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/features/avisos/data/api_push_registration.dart';
import 'package:vecinal/features/avisos/data/firebase_push_platform.dart';
import 'package:vecinal/features/avisos/data/push_service.dart';
import 'package:vecinal/features/avisos/domain/push_platform.dart';
import 'package:vecinal/features/avisos/domain/push_registration.dart';

/// Integration seam for Lot A. Null until real OTP authentication is available.
final pushCredentialsProvider = Provider<PushCredentials?>((ref) => null);
final pushPlatformProvider = Provider<PushPlatform>((ref) => FirebasePushPlatform());
final foregroundPushProvider = NotifierProvider<ForegroundPush, Map<String, String>?>(
  ForegroundPush.new,
);
final pushNavigationProvider = NotifierProvider<PushNavigation, String?>(PushNavigation.new);

class PushNavigation extends Notifier<String?> {
  @override
  String? build() => null;
  void open(String route) => state = route;
  void clear() => state = null;
}

class ForegroundPush extends Notifier<Map<String, String>?> {
  @override
  Map<String, String>? build() => null;
  void show(Map<String, String> data) => state = data;
  void dismiss() => state = null;
}

final pushControllerProvider = NotifierProvider<PushController, PushStatus>(PushController.new);

class PushController extends Notifier<PushStatus> {
  PushService? _service;

  @override
  PushStatus build() {
    if (!ref.watch(environmentProvider).enablePush) return PushStatus.disabled;
    final environment = ref.read(environmentProvider);
    final dio = Dio(
      BaseOptions(
        baseUrl: environment.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    final registrations = <String, ApiPushRegistration>{};
    final service = PushService(
      store: ref.read(secureStoreProvider),
      platform: ref.read(pushPlatformProvider),
      registrationFor: (credentials) {
        final registration = registrations.putIfAbsent(
          credentials.userId,
          () => ApiPushRegistration(
            dio: dio,
            store: ref.read(secureStoreProvider),
            credentials: credentials,
          ),
        );
        registration.credentials = credentials;
        return registration;
      },
      onStatus: (status) {
        if (ref.mounted) state = status;
      },
      navigate: (route) {
        if (ref.mounted) ref.read(pushNavigationProvider.notifier).open(route);
      },
      onForeground: (data) {
        if (ref.mounted) ref.read(foregroundPushProvider.notifier).show(data);
      },
    );
    _service = service;
    ref.listen(pushCredentialsProvider, (_, next) => unawaited(service.updateSession(next)));
    final connection = Connectivity().onConnectivityChanged.listen((values) {
      if (!values.contains(ConnectivityResult.none))
        unawaited(service.start(ref.read(pushCredentialsProvider)));
    });
    ref.onDispose(() {
      unawaited(connection.cancel());
      unawaited(service.dispose());
      dio.close();
    });
    // Avoid updating notifier state during build or requesting OS permission on launch.
    Future.microtask(() {
      if (ref.mounted) unawaited(service.start(ref.read(pushCredentialsProvider)));
    });
    return PushStatus.loading;
  }

  Future<void> enable() async {
    await _service?.start(ref.read(pushCredentialsProvider));
    await _service?.refresh(requestPermission: true);
  }

  Future<void> refresh() async {
    await _service?.start(ref.read(pushCredentialsProvider));
  }

  Future<void> signOut() async {
    await _service?.signOut();
  }

  void open(Map<String, String> data) => _service?.openMessage(data);
}
