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
    final contacts = [
      (l10n.protoFirefighters, Icons.local_fire_department_outlined),
      (l10n.protoPolice, Icons.local_police_outlined),
      (l10n.protoAmbulance, Icons.medical_services_outlined),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.protoEmergency), leading: const ProtoBackButton()),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  color: kErrorColor.withValues(alpha: 0.06),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 34, color: kErrorColor),
                        const SizedBox(height: 16),
                        Text(
                          l10n.protoEmergencyHeading,
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.protoEmergencyHint, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                for (final (label, icon) in contacts) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      minTileHeight: 68,
                      leading: Icon(icon, color: kErrorColor),
                      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                Text(l10n.connectsNeighbors, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 20),
                ProtoButton(
                  key: const ValueKey<String>('emergency-back-to-wall'),
                  text: l10n.postDetailBack,
                  icon: Icons.arrow_back,
                  onPressed: () => context.go(ProtoRoutes.home(ProtoHomeTab.wall)),
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
