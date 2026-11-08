import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/features/onboarding/tutorial_provider.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Pantalla de tutorial sobre la pantalla real del muro.
///
/// Se muestra la primera vez que se abre la app y se puede repetir desde el menú.
class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  final _publishKey = GlobalKey();
  final _takeFavorKey = GlobalKey();
  final _savedKey = GlobalKey();
  final _reviewKey = GlobalKey();
  final _emergencyKey = GlobalKey();

  final List<GlobalKey> _steps = [];
  late final ShowcaseView _showcase;

  @override
  void initState() {
    super.initState();
    _steps.addAll([_publishKey, _takeFavorKey, _savedKey, _reviewKey, _emergencyKey]);
    _showcase = ShowcaseView.register(onFinish: _finishTutorial);
  }

  void _startTutorial() {
    _showcase.startShowCase(_steps);
  }

  Future<void> _finishTutorial() async {
    await ref.read(tutorialSeenProvider.notifier).markSeen();
    if (!mounted) return;
    context.go(Routes.home);
  }

  @override
  void dispose() {
    _showcase.unregister();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.tutorialTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(Routes.home),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.tips_and_updates, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(texts.tutorialTitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Text(
              texts.tutorialSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            LargeButton(
              icon: Icons.play_arrow,
              label: texts.startTutorial,
              fullWidth: true,
              onPressed: _startTutorial,
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () => context.go(Routes.home), child: Text(texts.skipTutorial)),
          ],
        ),
      ),
    );
  }
}

/// Paso del tutorial: botón "+" del muro.
class PublishTutorialStep extends StatelessWidget {
  const PublishTutorialStep({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: _publishStepKey,
      description: AppLocalizations.of(context).tutorialPublishStep,
      child: child,
    );
  }

  static final GlobalKey _publishStepKey = GlobalKey();
}

/// Paso del tutorial: tomar favor en una tarjeta.
class TakeFavorTutorialStep extends StatelessWidget {
  const TakeFavorTutorialStep({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: _takeFavorStepKey,
      description: AppLocalizations.of(context).tutorialTakeFavorStep,
      child: child,
    );
  }

  static final GlobalKey _takeFavorStepKey = GlobalKey();
}

/// Paso del tutorial: estado Guardado en tu celular.
class SavedTutorialStep extends StatelessWidget {
  const SavedTutorialStep({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: _savedStepKey,
      description: AppLocalizations.of(context).tutorialSavedStep,
      child: child,
    );
  }

  static final GlobalKey _savedStepKey = GlobalKey();
}

/// Paso del tutorial: bandeja Acciones por revisar.
class ReviewTutorialStep extends StatelessWidget {
  const ReviewTutorialStep({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: _reviewStepKey,
      description: AppLocalizations.of(context).tutorialReviewStep,
      child: child,
    );
  }

  static final GlobalKey _reviewStepKey = GlobalKey();
}

/// Paso del tutorial: teléfonos de emergencia.
class EmergencyTutorialStep extends StatelessWidget {
  const EmergencyTutorialStep({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Showcase(
      key: _emergencyStepKey,
      description:
          '${AppLocalizations.of(context).tutorialEmergencyStep} '
          '${AppLocalizations.of(context).tutorialEmergencyNote}',
      child: child,
    );
  }

  static final GlobalKey _emergencyStepKey = GlobalKey();
}

/// Botón para iniciar el tutorial (usado en el menú de la barra superior).
class TutorialButton extends ConsumerWidget {
  const TutorialButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    return TextButton.icon(
      icon: const Icon(Icons.tips_and_updates),
      label: Text(texts.viewTutorial),
      onPressed: () => context.push('/tutorial'),
    );
  }
}
