import 'package:flutter/services.dart';

/// Serializes native protection across route transitions, including overlapping routes.
class SensitiveScreenProtection {
  SensitiveScreenProtection({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('pe.shabatshalom.vecinal/pantalla_sensible');

  static final shared = SensitiveScreenProtection();

  final MethodChannel _channel;
  final _owners = <Object>{};
  Future<void> _operation = Future.value();

  Future<void> protect(Object owner) => _serialize(() async {
    if (_owners.isEmpty) await _channel.invokeMethod<void>('setEnabled', true);
    _owners.add(owner);
  });

  Future<void> release(Object owner) => _serialize(() async {
    if (_owners.remove(owner) && _owners.isEmpty) {
      await _channel.invokeMethod<void>('setEnabled', false);
    }
  });

  Future<void> foregroundReady(Object owner) => _serialize(() async {
    if (_owners.contains(owner)) await _channel.invokeMethod<void>('foregroundReady');
  });

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operation.then((_) => action());
    _operation = next.then((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
