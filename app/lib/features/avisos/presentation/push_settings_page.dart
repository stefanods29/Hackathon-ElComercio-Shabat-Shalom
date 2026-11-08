import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/core/theme/vecinal_tokens.dart';
import 'package:vecinal/features/avisos/data/push_service.dart';
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
    final tokens = context.vecinalTokens;
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
          padding: EdgeInsets.all(tokens.spaceXl),
          children: [
            Icon(
              status == PushStatus.ready
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: tokens.spaceXl),
            Text(texts.pushHeading, style: Theme.of(context).textTheme.headlineSmall),
            SizedBox(height: tokens.spaceSm),
            Semantics(liveRegion: true, child: Text(description)),
            SizedBox(height: tokens.spaceLg),
            Text(texts.pushPrivacy),
            if (status != PushStatus.disabled && status != PushStatus.loading) ...[
              SizedBox(height: tokens.spaceXl),
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
