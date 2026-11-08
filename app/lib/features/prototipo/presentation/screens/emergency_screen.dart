import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.protoEmergency), leading: const ProtoBackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(Icons.error_outline, size: 64, color: kErrorColor),
            const SizedBox(height: 24),
            Text(
              l10n.protoEmergencyHeading,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 16),
            Text(l10n.protoEmergencyHint, textAlign: TextAlign.center),
            const SizedBox(height: 28),
            // Calls remain placeholders in this UI prototype.
            ProtoButton(
              text: l10n.protoFirefighters,
              icon: Icons.local_fire_department,
              onPressed: () {},
              fullWidth: true,
              secondary: true,
            ),
            const SizedBox(height: 14),
            ProtoButton(
              text: l10n.protoPolice,
              icon: Icons.local_police,
              onPressed: () {},
              fullWidth: true,
              secondary: true,
            ),
            const SizedBox(height: 14),
            ProtoButton(
              text: l10n.protoAmbulance,
              icon: Icons.medical_services,
              onPressed: () {},
              fullWidth: true,
              secondary: true,
            ),
            const SizedBox(height: 28),
            Text(l10n.connectsNeighbors, textAlign: TextAlign.center),
            const SizedBox(height: 28),
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
