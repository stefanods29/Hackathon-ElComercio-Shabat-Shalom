import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

typedef OperationalPrompt = ({String reason, String title, String cancel, String deviceCredential});

abstract interface class OperationalLock {
  Future<bool> authenticate(OperationalPrompt prompt);
  Future<void> cancel();
}

class DeviceOperationalLock implements OperationalLock {
  final _auth = LocalAuthentication();

  @override
  Future<bool> authenticate(OperationalPrompt prompt) async {
    try {
      // The operating system accepts a biometric or its own device credential.
      return await _auth.authenticate(
        localizedReason: prompt.reason,
        authMessages: [
          AndroidAuthMessages(
            signInHint: prompt.reason,
            signInTitle: prompt.title,
            cancelButton: prompt.cancel,
          ),
          IOSAuthMessages(
            cancelButton: prompt.cancel,
            localizedFallbackTitle: prompt.deviceCredential,
          ),
        ],
      );
    } on LocalAuthException {
      return false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _auth.stopAuthentication();
    } on PlatformException {
      // The platform may have dismissed its prompt already.
    } on MissingPluginException {
      // There is no native prompt to dismiss.
    }
  }
}

/// Unlocks only this view. Case authorization and expiration stay in its repository.
class OperationalAccess extends ChangeNotifier {
  OperationalAccess({
    required this._lock,
    required this._clock,
    required this._beforeReveal,
    required this._foreground,
    this._inactivity = const Duration(minutes: 5),
  });

  final OperationalLock _lock;
  final DateTime Function() _clock;
  final Future<void> Function() _beforeReveal;
  final Duration _inactivity;
  bool _foreground;
  bool _disposed = false;
  bool _authenticating = false;
  bool _checking = false;
  bool _reviewed = false;
  int _reviewGeneration = 0;
  Timer? _timer;
  DateTime? _lastActivity;
  bool _failed = false;

  bool get failed => _failed;
  bool get busy => _authenticating || _checking;
  bool get canReveal => _foreground && _reviewed && _withinIdleLimit;

  bool get _withinIdleLimit {
    final last = _lastActivity;
    if (last == null) return false;
    final now = _clock();
    return !now.isBefore(last) && now.isBefore(last.add(_inactivity));
  }

  Future<void> unlock(OperationalPrompt prompt) async {
    if (!_foreground || busy || canReveal) return;
    _authenticating = true;
    _failed = false;
    notifyListeners();
    var accepted = false;
    try {
      accepted = await _lock.authenticate(prompt);
    } catch (_) {
      // A failing authenticator cannot unlock the view.
    }
    if (_disposed) return;
    _authenticating = false;
    if (!accepted) {
      _failed = true;
      _expire();
      return;
    }
    _restartTimer();
    if (_foreground) await _review();
  }

  void recordActivity() {
    if (canReveal) _restartTimer();
  }

  Future<void> setForeground(bool foreground) async {
    if (_foreground == foreground) return;
    _foreground = foreground;
    _reviewGeneration++;
    _reviewed = false;
    _checking = false;
    if (foreground && _withinIdleLimit) {
      await _review();
    } else if (foreground) {
      _expire();
    } else {
      notifyListeners();
    }
  }

  void _restartTimer() {
    _lastActivity = _clock();
    _timer?.cancel();
    _timer = Timer(_inactivity, _expire);
  }

  void _expire() {
    _timer?.cancel();
    _lastActivity = null;
    _reviewed = false;
    _checking = false;
    _reviewGeneration++;
    notifyListeners();
  }

  Future<void> _review() async {
    final generation = ++_reviewGeneration;
    _checking = true;
    notifyListeners();
    var valid = true;
    try {
      await _beforeReveal();
    } catch (_) {
      valid = false;
    }
    if (_disposed || generation != _reviewGeneration) return;
    _checking = false;
    if (!valid || !_withinIdleLimit) {
      _failed = !valid;
      _expire();
      return;
    }
    _reviewed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_authenticating) unawaited(_lock.cancel());
    super.dispose();
  }
}
