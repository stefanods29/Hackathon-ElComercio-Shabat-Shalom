import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A contact chosen in the phone's own picker. The app never reads the rest of the agenda, so it
/// needs no permission to the contacts.
class PickedContact {
  const PickedContact({required this.name, required this.phones});
  final String name;

  /// The number the neighbor tapped first, then the others of that contact.
  final List<String> phones;
}

abstract interface class ContactPicker {
  /// Null when the neighbor closed the picker without choosing.
  Future<PickedContact?> pick();
}

class SystemContactPicker implements ContactPicker {
  const SystemContactPicker();
  static const _channel = MethodChannel('pe.shabatshalom.vecinal/agenda');

  @override
  Future<PickedContact?> pick() async {
    final result = await _channel.invokeMapMethod<String, Object?>('pickContact');
    if (result == null) return null;
    final phones = [
      for (final phone in result['phones'] as List<Object?>? ?? const [])
        if (phone is String && phone.trim().isNotEmpty) phone.trim(),
    ];
    return PickedContact(name: (result['name'] as String? ?? '').trim(), phones: phones);
  }
}

final contactPickerProvider = Provider<ContactPicker>((ref) => const SystemContactPicker());

/// Whether the phone will show the notification. Asking for the permission, when the phone needs
/// it, happens inside the call.
enum LocalNotificationResult { scheduled, denied, failed }

/// A notification of the phone itself, made on the phone: it never travels through a server.
abstract interface class LocalNotifier {
  Future<LocalNotificationResult> show({
    required String title,
    required String body,
    Duration delay = Duration.zero,
  });
}

class SystemLocalNotifier implements LocalNotifier {
  const SystemLocalNotifier();
  static const _channel = MethodChannel('pe.shabatshalom.vecinal/avisos_locales');

  @override
  Future<LocalNotificationResult> show({
    required String title,
    required String body,
    Duration delay = Duration.zero,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('show', {
        'title': title,
        'body': body,
        'delayMs': delay.inMilliseconds,
      });
      return switch (result) {
        'scheduled' => LocalNotificationResult.scheduled,
        'denied' => LocalNotificationResult.denied,
        _ => LocalNotificationResult.failed,
      };
    } on PlatformException {
      return LocalNotificationResult.failed;
    } on MissingPluginException {
      return LocalNotificationResult.failed;
    }
  }
}

final localNotifierProvider = Provider<LocalNotifier>((ref) => const SystemLocalNotifier());
