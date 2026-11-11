import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/platform/device_services.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/features/avisos/data/push_service.dart';
import 'package:vecinal/features/cuenta/presentation/account_ui.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class PushSettingsPage extends ConsumerStatefulWidget {
  const PushSettingsPage({super.key});
  @override
  ConsumerState<PushSettingsPage> createState() => _PushSettingsPageState();
}

class _PushSettingsPageState extends ConsumerState<PushSettingsPage> with WidgetsBindingObserver {
  bool _simulating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(pushControllerProvider.notifier).refresh());
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final status = ref.watch(pushControllerProvider);
    final description = switch (status) {
      PushStatus.disabled => texts.pushDisabled,
      PushStatus.loading => texts.pushLoading,
      PushStatus.permissionNeeded => texts.pushPermissionExplanation,
      PushStatus.denied => texts.pushDeniedHelp,
      PushStatus.waitingForSession => texts.pushWaitingSession,
      PushStatus.pending => texts.pushPending,
      PushStatus.ready => texts.pushReady,
      PushStatus.failed => texts.pushFailed,
    };
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ready = status == PushStatus.ready;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    return Scaffold(
      appBar: AppBar(title: Text(texts.pushTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: spaced([
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Row(
                      children: [
                        AccountIcon(
                          icon: ready
                              ? Icons.notifications_active_outlined
                              : Icons.notifications_outlined,
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(texts.pushHeading, style: theme.textTheme.titleLarge)),
                      ],
                    ),
                    Semantics(liveRegion: true, child: Text(description)),
                    if (status != PushStatus.disabled && status != PushStatus.loading)
                      FilledButton(
                        onPressed: ref.read(pushControllerProvider.notifier).enable,
                        child: Text(
                          status == PushStatus.permissionNeeded
                              ? texts.pushEnable
                              : texts.pushCheckAgain,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(child: Icon(Icons.lock_outline, size: 20, color: scheme.primary)),
                const SizedBox(width: 10),
                Expanded(child: Text(texts.pushPrivacy, style: muted)),
              ],
            ),
            if (ref.watch(practiceModeProvider).value == true) ...[
              EmergencyNotice(
                icon: Icons.science_outlined,
                text: texts.pushPracticeHelp,
                tone: NoticeTone.info,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.campaign_outlined),
                label: Text(texts.pushPracticeSimulate),
                onPressed: _simulating ? null : _simulate,
              ),
            ],
          ]),
        ),
      ),
    );
  }

  /// The banner of a notice that arrives with Winki open, and a notification of this phone a
  /// few seconds later, like the one of any app. Neither leaves this phone.
  Future<void> _simulate() async {
    final texts = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _simulating = true);
    ref.read(foregroundPushProvider.notifier).show(const {'tipo': 'modo_emergencia_activado'});
    final result = await ref
        .read(localNotifierProvider)
        .show(
          title: texts.pushUrgentTitle,
          body: texts.pushUrgentBody,
          delay: const Duration(seconds: 5),
        );
    if (!mounted) return;
    setState(() => _simulating = false);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            LocalNotificationResult.scheduled => texts.pushLocalScheduled,
            LocalNotificationResult.denied => texts.pushLocalDenied,
            LocalNotificationResult.failed => texts.pushLocalFailed,
          }),
        ),
      );
  }
}
