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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.viewTutorial), leading: const ProtoBackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.protoWelcomeHeading, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 24),
            _step(1, l10n.protoThreeTapsTitle, l10n.protoThreeTapsHint),
            const SizedBox(height: 20),
            _step(2, l10n.protoTakeFavorTitle, l10n.protoTakeFavorHint),
            const SizedBox(height: 20),
            _step(3, l10n.protoStatusesTitle, l10n.tutorialSavedStep),
            const SizedBox(height: 20),
            _step(4, l10n.actionsToReview, l10n.tutorialReviewStep),
            const SizedBox(height: 20),
            _step(5, l10n.protoEmergency, l10n.emergencyLifeRisk),
            const SizedBox(height: 32),
            ProtoButton(
              text: l10n.protoStartUsing,
              icon: Icons.check_circle_outline,
              onPressed: () => ProtoNavigation.back(context),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(int number, String title, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: kPrimaryColor, borderRadius: BorderRadius.circular(12)),
        child: Text(
          '$number',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kTextColor),
            ),
            const SizedBox(height: 6),
            Text(text),
          ],
        ),
      ),
    ],
  );
}
