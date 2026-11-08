import 'dart:async';
import 'dart:convert';

import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/avisos/domain/notification_route.dart';
import 'package:vecinal/features/avisos/domain/push_platform.dart';
import 'package:vecinal/features/avisos/domain/push_registration.dart';

enum PushStatus {
  disabled,
  loading,
  permissionNeeded,
  denied,
  waitingForSession,
  pending,
  ready,
  failed,
}

/// Serializes token/session changes. Native Firebase and the API can be replaced independently.
class PushService {
  PushService({
    required this.platform,
    required this.registrationFor,
    required this.onStatus,
    required this.navigate,
    required this.onForeground,
    required this.store,
    this.confirmUrgent,
  });
  final PushPlatform platform;
  final SecureStore store;
  final PushRegistration Function(PushCredentials) registrationFor;
  final void Function(PushStatus) onStatus;
  final void Function(String) navigate;
  final void Function(Map<String, String>) onForeground;

  /// Confirms an opened urgent notice in the API (Phase 2, Lot C); its errors never change the
  /// push status.
  final Future<void> Function(PushCredentials session, String noticeId)? confirmUrgent;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _tail = Future.value();
  PushCredentials? _session;
  PushRegistration? _registration;
  String? _token;
  String? _topic;
  String? _pendingRoute;

  /// Urgent notice opened before the session of this run was ready.
  String? _pendingUrgent;
  bool _initialized = false;
  bool _disposed = false;
  bool _registeredThisRun = false;
  String? _savedOwner;
  PushCredentials? _desiredSession;

  Future<void> _run(Future<void> Function() action) {
    final result = _tail.then((_) async {
      if (_disposed) return;
      try {
        await action();
      } catch (_) {
        if (!_disposed) onStatus(PushStatus.failed);
      }
    });
    _tail = result;
    return result;
  }

  Future<void> start(PushCredentials? session) {
    _desiredSession = session;
    return _run(() async {
      onStatus(PushStatus.loading);
      if (!_initialized) {
        await platform.initialize();
        _initialized = true;
        final saved = await store.read('push.installation');
        if (saved != null) {
          final data = jsonDecode(saved) as Map<String, dynamic>;
          _savedOwner = data['owner'] as String?;
          _token = data['token'] as String?;
          _topic = data['topic'] as String?;
          _pendingRoute = data['route'] as String?;
        }
        _subscriptions.add(
          platform.tokenChanges.listen(
            (token) => unawaited(_run(() => _registerToken(token))),
            onError: (Object _) {
              if (!_disposed) onStatus(PushStatus.failed);
            },
          ),
        );
        _subscriptions.add(platform.openedMessages.listen(_open));
        _subscriptions.add(platform.foregroundMessages.listen(onForeground));
        final initial = await platform.initialMessage();
        if (initial != null) _open(initial);
      }
      await _changeSession(_desiredSession);
      await _refresh();
    });
  }

  Future<void> updateSession(PushCredentials? session) {
    _desiredSession = session;
    return _run(() async {
      await _changeSession(_desiredSession);
      if (_initialized) await _refresh();
    });
  }

  Future<void> _changeSession(PushCredentials? session) async {
    if ((_session?.userId ?? _savedOwner) != session?.userId) {
      await _detach();
      _session = session;
      _registration = session == null ? null : registrationFor(session);
    } else {
      _session = session;
      if (session != null) _registration = registrationFor(session);
    }
    _savedOwner = session?.userId;
    final topic = session?.zoneId == null ? null : 'zona-${session!.zoneId}';
    if (_topic != null && _topic != topic) {
      await platform.unsubscribe(_topic!);
      _topic = null;
    }
    if (session != null && _pendingRoute != null) {
      navigate(_pendingRoute!);
      _pendingRoute = null;
    }
    final urgent = _pendingUrgent;
    if (session != null && urgent != null) {
      _pendingUrgent = null;
      _sendConfirmation(session, urgent);
    }
    await _persist();
  }

  /// Lot A calls this before deleting credentials. Also invalidates the FCM installation token.
  Future<void> signOut() => updateSession(null);

  Future<void> _detach() async {
    // Invalidate at Firebase even when the REST service is unavailable.
    try {
      if (_token != null) await _registration?.unregister(_token!);
    } finally {
      try {
        if (_topic != null) {
          await platform.unsubscribe(_topic!);
          _topic = null;
        }
      } finally {
        if (_token != null) {
          await platform.deleteToken();
          _token = null;
        }
        _registeredThisRun = false;
        await _persist();
      }
    }
  }

  Future<void> refresh({bool requestPermission = false}) =>
      _run(() => _refresh(requestPermission: requestPermission));

  Future<void> _refresh({bool requestPermission = false}) async {
    if (!_initialized) return;
    await _changeSession(_desiredSession);
    final permission = await platform.permission(request: requestPermission);
    if (permission != PushPermission.allowed) {
      await _detach();
      onStatus(
        permission == PushPermission.denied ? PushStatus.denied : PushStatus.permissionNeeded,
      );
      return;
    }
    if (_session == null) {
      onStatus(PushStatus.waitingForSession);
      return;
    }
    final token = await platform.token();
    if (token == null) {
      onStatus(PushStatus.pending);
      return;
    }
    await _registerToken(token);
  }

  Future<void> _registerToken(String token) async {
    if (_disposed ||
        _session == null ||
        _registration == null ||
        _session?.userId != _desiredSession?.userId) {
      return;
    }
    if (await platform.permission() != PushPermission.allowed) return;
    final previous = _token;
    _token = token;
    await _persist();
    final sent = previous == token && _registeredThisRun
        ? await _registration!.retry()
        : await _registration!.register(token, platform.devicePlatform);
    _registeredThisRun = true;
    if (previous != null && previous != token) await _registration!.unregister(previous);
    if (_disposed || _session?.userId != _desiredSession?.userId) return;
    if (previous != token) _topic = null;
    final zoneId = _session!.zoneId;
    if (zoneId != null && _topic == null) {
      _topic = 'zona-$zoneId';
      try {
        await platform.subscribe(_topic!);
      } catch (_) {
        _topic = null;
        rethrow;
      }
    }
    await _persist();
    onStatus(sent && await _registration!.retry() ? PushStatus.ready : PushStatus.pending);
  }

  void _open(Map<String, String> data) {
    final urgent = urgentNoticeIdFor(data);
    if (urgent != null && !_disposed) _confirmUrgent(urgent);
    final route = routeFor(data);
    if (route == null || _disposed) return;
    if (_session == null || _session?.userId != _desiredSession?.userId) {
      _pendingRoute = route;
      unawaited(_run(_persist));
    } else {
      navigate(route);
    }
  }

  void openMessage(Map<String, String> data) => _open(data);

  /// Opening an urgent notice confirms it, which stops its SMS backup. Without the session of this
  /// run yet, the confirmation waits for it (in memory only: the SMS remains the backup).
  void _confirmUrgent(String noticeId) {
    final session = _session;
    if (session == null || session.userId != _desiredSession?.userId) {
      _pendingUrgent = noticeId;
      return;
    }
    _sendConfirmation(session, noticeId);
  }

  void _sendConfirmation(PushCredentials session, String noticeId) {
    unawaited(confirmUrgent?.call(session, noticeId).catchError((Object _) {}));
  }

  Future<void> _persist() => store.write(
    'push.installation',
    jsonEncode({
      'owner': _savedOwner ?? _session?.userId,
      'token': _token,
      'topic': _topic,
      'route': _pendingRoute,
    }),
  );

  Future<void> dispose() async {
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
  }
}
