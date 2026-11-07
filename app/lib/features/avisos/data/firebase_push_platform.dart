import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:vecinal/features/avisos/domain/push_platform.dart';

Map<String, String> _stringData(RemoteMessage message) =>
    message.data.map((key, value) => MapEntry(key, value.toString()));

/// Android needs a top-level entry point. No private content is processed in the background.
@pragma('vm:entry-point')
Future<void> handleBackgroundPush(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FirebasePushPlatform implements PushPlatform {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  @override
  String get devicePlatform => defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  @override
  Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(handleBackgroundPush);
    // Foreground messages have an in-app banner, avoiding a duplicate iOS system alert.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  @override
  Future<PushPermission> permission({bool request = false}) async {
    final settings = request
        ? await _messaging.requestPermission()
        : await _messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized || AuthorizationStatus.provisional => PushPermission.allowed,
      AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently => PushPermission.denied,
      AuthorizationStatus.notDetermined => PushPermission.undetermined,
    };
  }

  @override
  Future<String?> token() async {
    if (defaultTargetPlatform == TargetPlatform.iOS && await _messaging.getAPNSToken() == null) {
      return null;
    }
    // Subscribe before register(): Firebase Messaging 17 emits a Firebase Installation ID.
    final registered = Completer<String>();
    final subscription = _messaging.onRegistered.listen((value) {
      if (!registered.isCompleted) registered.complete(value);
    });
    try {
      await _messaging.register().timeout(const Duration(seconds: 20));
      return await registered.future.timeout(const Duration(seconds: 20));
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> deleteToken() => _messaging.unregister();
  @override
  Future<void> subscribe(String topic) => _messaging.subscribeToTopic(topic);
  @override
  Future<void> unsubscribe(String topic) => _messaging.unsubscribeFromTopic(topic);
  @override
  Future<Map<String, String>?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _stringData(message);
  }

  @override
  Stream<String> get tokenChanges => _messaging.onRegistered;
  @override
  Stream<Map<String, String>> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_stringData);
  @override
  Stream<Map<String, String>> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_stringData);
}
