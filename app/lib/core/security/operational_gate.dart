import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vecinal/core/security/operational_lock.dart';
import 'package:vecinal/core/security/sensitive_screen_protection.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// The builder runs only after native shielding, device authentication and a fresh cache check.
class OperationalGate extends StatefulWidget {
  const OperationalGate({
    super.key,
    required this.lock,
    required this.protection,
    required this.clock,
    required this.beforeReveal,
    required this.builder,
  });

  final OperationalLock lock;
  final SensitiveScreenProtection protection;
  final DateTime Function() clock;
  final Future<void> Function() beforeReveal;
  final Widget Function(BuildContext context, VoidCallback recordActivity) builder;

  @override
  State<OperationalGate> createState() => _OperationalGateState();
}

class _OperationalGateState extends State<OperationalGate> {
  final _owner = Object();
  late final OperationalAccess _access;
  late final AppLifecycleListener _lifecycle;
  late final SensitiveScreenProtection _protection;
  bool? _protected;

  @override
  void initState() {
    super.initState();
    _protection = widget.protection;
    _access = OperationalAccess(
      lock: widget.lock,
      clock: widget.clock,
      beforeReveal: widget.beforeReveal,
      foreground: _isForeground,
    );
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        unawaited(_access.setForeground(state == AppLifecycleState.resumed));
        if (state == AppLifecycleState.resumed) _foregroundReady();
      },
    );
    unawaited(_protect());
  }

  bool get _isForeground =>
      (WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed) ==
      AppLifecycleState.resumed;

  Future<void> _protect() async {
    var protected = true;
    try {
      await _protection.protect(_owner);
    } on PlatformException {
      protected = false;
    } on MissingPluginException {
      protected = false;
    }
    if (!mounted) return;
    setState(() => _protected = protected);
    if (protected) _foregroundReady();
  }

  void _foregroundReady() {
    // iOS keeps the old frame covered until Flutter has drawn either the gate or a reviewed case.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isForeground && _protected == true) {
        unawaited(_finishNativeTransition(() => _protection.foregroundReady(_owner)));
      }
    });
  }

  Future<void> _finishNativeTransition(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException {
      // If removal fails, the native protection stays in place.
    } on MissingPluginException {
      // No native protection was installed on this platform.
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _access.dispose();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_finishNativeTransition(() => _protection.release(_owner)));
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _access,
      builder: (context, _) {
        if (_protected == true && _access.canReveal) {
          return Listener(
            onPointerDown: (_) => _access.recordActivity(),
            onPointerMove: (_) => _access.recordActivity(),
            onPointerSignal: (_) => _access.recordActivity(),
            child: Focus(
              onKeyEvent: (_, _) {
                _access.recordActivity();
                return KeyEventResult.ignored;
              },
              child: widget.builder(context, _access.recordActivity),
            ),
          );
        }
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _protected == false ? texts.operationalProtectionFailed : texts.operationalLocked,
                ),
                if (_access.failed) Text(texts.operationalUnlockFailed),
                if (_protected != false)
                  FilledButton(
                    onPressed: _protected == true && !_access.busy
                        ? () => _access.unlock((
                            reason: texts.operationalUnlockReason,
                            title: texts.operationalTitle,
                            cancel: texts.cancelAction,
                            deviceCredential: texts.operationalDeviceCredential,
                          ))
                        : null,
                    child: Text(texts.operationalUnlock),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
