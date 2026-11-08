import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      (l10n.protoThreeTapsTitle, l10n.protoThreeTapsHint),
      (l10n.protoTakeFavorTitle, l10n.protoTakeFavorHint),
      (l10n.protoStatusesTitle, l10n.tutorialSavedStep),
      (l10n.actionsToReview, l10n.tutorialReviewStep),
      (l10n.protoEmergency, l10n.emergencyLifeRisk),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.viewTutorial), leading: const ProtoBackButton()),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(l10n.protoWelcomeHeading, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 20),
                for (var i = 0; i < steps.length; i++) ...[
                  _TutorialStep(number: i + 1, title: steps[i].$1, body: steps[i].$2),
                  if (i != steps.length - 1) const SizedBox(height: 8),
                ],
                const SizedBox(height: 24),
                ProtoButton(
                  key: const ValueKey<String>('tutorial-start'),
                  text: l10n.protoStartUsing,
                  icon: Icons.check_circle_outline,
                  onPressed: () => ProtoNavigation.back(context),
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TutorialStep extends StatelessWidget {
  const _TutorialStep({required this.number, required this.title, required this.body});

  final int number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: kPrimaryColor, shape: BoxShape.circle),
            child: Text(
              '$number',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
