import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/features/avisos/data/push_service.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class PushSettingsPage extends ConsumerStatefulWidget {
  const PushSettingsPage({super.key});
  @override
  ConsumerState<PushSettingsPage> createState() => _PushSettingsPageState();
}

class _PushSettingsPageState extends ConsumerState<PushSettingsPage> with WidgetsBindingObserver {
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
    return Scaffold(
      appBar: AppBar(title: Text(texts.pushTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Icon(
              status == PushStatus.ready
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(texts.pushHeading, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(description)),
            const SizedBox(height: 16),
            Text(texts.pushPrivacy),
            if (ref.watch(practiceModeProvider).value == true) ...[
              const SizedBox(height: 24),
              Text(texts.pushPracticeHelp),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.campaign_outlined),
                label: Text(texts.pushPracticeSimulate),
                onPressed: () => ref.read(foregroundPushProvider.notifier).show(const {
                  'tipo': 'modo_emergencia_activado',
                }),
              ),
            ],
            if (status != PushStatus.disabled && status != PushStatus.loading) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: ref.read(pushControllerProvider.notifier).enable,
                child: Text(
                  status == PushStatus.permissionNeeded ? texts.pushEnable : texts.pushCheckAgain,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
