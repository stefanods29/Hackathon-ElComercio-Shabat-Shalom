import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Signs out after [ConsoleEnvironment.inactivity] without keyboard or pointer activity, and warns
/// a minute before. Any key, click, scroll or mouse movement keeps working (WCAG 2.2.1).
///
/// It compares wall-clock times, so a background tab whose timers the browser slows down still
/// signs out on time when it comes back.
class InactivityGuard extends ConsumerStatefulWidget {
  const InactivityGuard({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends ConsumerState<InactivityGuard> {
  static const _warningLead = Duration(seconds: 60);

  late DateTime _lastActivity;
  Timer? _ticker;
  int? _secondsLeft;
  bool _signingOut = false;

  DateTime _now() => ref.read(clockProvider)();

  @override
  void initState() {
    super.initState();
    _lastActivity = _now();
    HardwareKeyboard.instance.addHandler(_onKey);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool _onKey(KeyEvent event) {
    _activity();
    // Never consumes the key: it only counts as activity.
    return false;
  }

  void _activity() {
    _lastActivity = _now();
    if (_secondsLeft != null && mounted) setState(() => _secondsLeft = null);
  }

  void _tick() {
    if (_signingOut || !mounted) return;
    final timeout = ref.read(consoleEnvironmentProvider).inactivity;
    final idle = _now().difference(_lastActivity);
    if (idle >= timeout) {
      _signingOut = true;
      unawaited(ref.read(sessionProvider.notifier).signOut(SignOutReason.inactivity));
      return;
    }
    final left = timeout - idle;
    final seconds = left <= _warningLead ? (left.inMilliseconds / 1000).ceil() : null;
    if (seconds != _secondsLeft) setState(() => _secondsLeft = seconds);
  }

  @override
  Widget build(BuildContext context) {
    final seconds = _secondsLeft;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _activity(),
      onPointerHover: (_) => _activity(),
      onPointerSignal: (_) => _activity(),
      child: Stack(
        children: [
          Positioned.fill(child: widget.child),
          if (seconds != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _InactivityWarning(seconds: seconds, onStay: _activity),
            ),
        ],
      ),
    );
  }
}

class _InactivityWarning extends StatelessWidget {
  const _InactivityWarning({required this.seconds, required this.onStay});

  final int seconds;
  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = TextStyle(color: scheme.onErrorContainer);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Material(
          elevation: 6,
          color: scheme.errorContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.onErrorContainer, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(Icons.timer_outlined, color: scheme.onErrorContainer),
                // Announced once when it appears; the countdown below is not a live region.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.inactivityWarningTitle,
                    style: text.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(l10n.inactivityWarningCountdown(seconds), style: text),
                FilledButton(onPressed: onStay, child: Text(l10n.inactivityStay)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
