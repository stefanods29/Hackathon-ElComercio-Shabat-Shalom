import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/spaced.dart';
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
  int _stepIndex = 0;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final practice = ref.watch(practiceModeProvider);
    final content = ref.watch(tutorialContentProvider);
    final steps = _started ? content.value?.steps : null;
    return Scaffold(
      appBar: AppBar(title: Text(t.tutorialTitle, maxLines: 2, overflow: TextOverflow.clip)),
      body: SafeArea(
        bottom: steps == null,
        child: !_started
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: spaced([
                  Text(t.tutorialSubtitle, style: theme.textTheme.headlineSmall),
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
                        if (value != null) {
                          ref.read(demoProfileIndexProvider.notifier).select(value);
                        }
                      },
                    ),
                  ],
                  FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(t.startTutorial),
                    onPressed: () => setState(() => _started = true),
                  ),
                  TextButton(onPressed: _finish, child: Text(t.finishTutorial)),
                ], gap: 16),
              )
            : content.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(t.actionFailed),
                    TextButton(onPressed: _finish, child: Text(t.finishTutorial)),
                  ],
                ),
                data: (data) {
                  final step = data.steps[_stepIndex];
                  return ListView(
                    key: ValueKey(step.destination),
                    padding: const EdgeInsets.all(24),
                    children: spaced([
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          child: Icon(_icon(step.destination), size: 34),
                        ),
                      ),
                      Semantics(
                        header: true,
                        child: Text(
                          step.title ?? _title(t, step.destination),
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      for (final paragraph in step.paragraphs(_body(t, step.destination)))
                        Text(paragraph),
                      if (step.destination == TutorialDestination.emergency)
                        Text(t.connectsNeighbors),
                      OutlinedButton(
                        onPressed: !practice.hasValue ? null : () => _open(step.destination),
                        child: Text(t.openStep),
                      ),
                    ], gap: 16),
                  );
                },
              ),
      ),
      bottomNavigationBar: steps == null
          ? null
          : Material(
              color: scheme.surfaceContainer,
              child: SafeArea(
                minimum: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 8,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: Text(t.tutorialProgress(_stepIndex + 1, steps.length)),
                    ),
                    Row(
                      spacing: 12,
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _stepIndex == 0 ? null : () => setState(() => _stepIndex--),
                            child: Text(t.tutorialPrevious, textAlign: TextAlign.center),
                          ),
                        ),
                        Expanded(
                          child: FilledButton(
                            onPressed: _stepIndex == steps.length - 1
                                ? _finish
                                : () => setState(() => _stepIndex++),
                            child: Text(
                              _stepIndex == steps.length - 1 ? t.finishTutorial : t.tutorialNext,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _finish() async {
    await ref.read(tutorialSeenProvider.notifier).markSeen();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  IconData _icon(TutorialDestination destination) => switch (destination) {
    TutorialDestination.directory => Icons.storefront_outlined,
    TutorialDestination.publish => Icons.add_circle_outline,
    TutorialDestination.review => Icons.star_outline,
    TutorialDestination.actions => Icons.inbox_outlined,
    TutorialDestination.emergency => Icons.emergency_outlined,
    TutorialDestination.privacy => Icons.shield_outlined,
  };

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
      TutorialDestination.directory => Routes.tutorialDirectory,
      TutorialDestination.publish => Routes.publishService,
      TutorialDestination.review =>
        service == null ? Routes.tutorialDirectory : '/servicios/${service.id}/resena',
      TutorialDestination.actions => Routes.toReview,
      TutorialDestination.emergency => Routes.tutorialEmergency,
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
