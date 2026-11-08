import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class ActionsToReviewScreen extends StatelessWidget {
  const ActionsToReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.actionsToReview), leading: const ProtoBackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.task_alt, size: 64, color: kPrimaryColor),
            const SizedBox(height: 20),
            Text(
              l10n.protoNoActions,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(l10n.protoReviewHint, textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ProtoButton(
              text: l10n.postDetailBack,
              icon: Icons.arrow_back,
              onPressed: () => context.go(ProtoRoutes.home(ProtoHomeTab.wall)),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
