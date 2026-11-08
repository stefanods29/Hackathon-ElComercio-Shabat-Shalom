import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/features/onboarding/tutorial_content.dart';
import 'package:vecinal/features/onboarding/tutorial_provider.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Every step has a real destination and works from the included public asset.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});
  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  bool _started = false;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final practice = ref.watch(practiceModeProvider);
    final content = ref.watch(tutorialContentProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.tutorialTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(t.tutorialSubtitle, style: Theme.of(context).textTheme.titleLarge),
            Text(t.tutorialFallback),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(t.practiceMode),
              subtitle: Text(practice.value == true ? t.practiceHelp : t.practiceOffHelp),
              value: practice.value == true,
              onChanged: !practice.hasValue
                  ? null
                  : (value) => ref.read(practiceModeProvider.notifier).set(value),
            ),
            if (practice.value == true) ...[
              Text(t.syntheticProfilesHelp),
              DropdownButtonFormField<int>(
                initialValue: ref.watch(demoProfileIndexProvider),
                isExpanded: true,
                decoration: InputDecoration(labelText: t.syntheticProfile),
                items: [
                  for (var i = 0; i < demoProfiles.length; i++)
                    DropdownMenuItem(value: i, child: Text(demoProfiles[i].name)),
                ],
                onChanged: (value) {
                  if (value != null) ref.read(demoProfileIndexProvider.notifier).select(value);
                },
              ),
            ],
            if (!_started)
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(t.startTutorial),
                onPressed: () => setState(() => _started = true),
              ),
            if (_started)
              content.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Text(t.actionFailed),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final step in data.steps)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                step.title ?? _title(t, step.destination),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(step.body ?? _body(t, step.destination)),
                              if (step.destination == TutorialDestination.emergency)
                                Text(t.connectsNeighbors),
                              OutlinedButton(
                                onPressed: !practice.hasValue
                                    ? null
                                    : () => _open(step.destination),
                                child: Text(t.openStep),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            TextButton(
              onPressed: () async {
                await ref.read(tutorialSeenProvider.notifier).markSeen();
                if (context.mounted) context.go(Routes.home);
              },
              child: Text(t.finishTutorial),
            ),
          ],
        ),
      ),
    );
  }

  String _title(AppLocalizations t, TutorialDestination d) => switch (d) {
    TutorialDestination.directory => t.directoryTitle,
    TutorialDestination.publish => t.offerService,
    TutorialDestination.review => t.writeReview,
    TutorialDestination.actions => t.actionsToReview,
    TutorialDestination.emergency => t.emergencyTitle,
    TutorialDestination.privacy => t.privacyTitle,
  };
  String _body(AppLocalizations t, TutorialDestination d) => switch (d) {
    TutorialDestination.directory => t.tutorialDirectoryStep,
    TutorialDestination.publish => t.tutorialPublishStep,
    TutorialDestination.review => t.tutorialReviewPilotStep,
    TutorialDestination.actions => t.tutorialReviewStep,
    TutorialDestination.emergency => t.emergencyLifeRisk,
    TutorialDestination.privacy => t.tutorialPrivacyStep,
  };
  void _open(TutorialDestination d) {
    final service = ref.read(servicesProvider(const ServiceQuery())).value?.firstOrNull;
    final route = switch (d) {
      TutorialDestination.directory => Routes.directory,
      TutorialDestination.publish => Routes.publishService,
      TutorialDestination.review =>
        service == null ? Routes.directory : '/servicios/${service.id}/resena',
      TutorialDestination.actions => Routes.toReview,
      TutorialDestination.emergency => Routes.emergencyDashboard,
      TutorialDestination.privacy => Routes.myData,
    };
    context.push(route);
  }
}

class TutorialButton extends StatelessWidget {
  const TutorialButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).viewTutorial,
    icon: const Icon(Icons.tips_and_updates_outlined),
    onPressed: () => context.push(Routes.tutorial),
  );
}
