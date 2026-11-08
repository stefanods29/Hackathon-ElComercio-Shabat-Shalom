import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).accountTitle),
      leading: const ProtoBackButton(),
    ),
    body: const AccountContent(),
  );
}

/// Shared between the home tab and the account route. Actions remain simulated.
class AccountContent extends StatelessWidget {
  const AccountContent({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: Color(0xFFE2E8F0),
                child: Icon(Icons.person, size: 48, color: kPrimaryColor),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Beto',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(l10n.protoDemoZone, textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ProtoButton(
              text: l10n.simpleModeTitle,
              icon: Icons.accessibility,
              onPressed: () {},
              fullWidth: true,
            ),
            const SizedBox(height: 12),
            ProtoButton(
              text: l10n.viewTutorial,
              icon: Icons.play_circle_outline,
              onPressed: () => ProtoNavigation.open(context, ProtoRoutes.tutorial),
              fullWidth: true,
            ),
            const SizedBox(height: 12),
            ProtoButton(
              text: l10n.protoEmergency,
              icon: Icons.warning_amber_outlined,
              onPressed: () => ProtoNavigation.open(context, ProtoRoutes.emergency),
              fullWidth: true,
              secondary: true,
            ),
            const SizedBox(height: 12),
            ProtoButton(
              text: l10n.pushTitle,
              icon: Icons.notifications_outlined,
              onPressed: () => ProtoNavigation.open(context, ProtoRoutes.pushSettings),
              fullWidth: true,
              secondary: true,
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            ProtoButton(
              text: l10n.lostPhone,
              icon: Icons.phone_disabled,
              onPressed: () {},
              fullWidth: true,
              secondary: true,
            ),
          ],
        ),
      ),
    );
  }
}
