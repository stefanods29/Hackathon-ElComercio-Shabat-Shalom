import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class PushSettingsScreen extends StatelessWidget {
  const PushSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pushTitle), leading: const ProtoBackButton()),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.protoSettingsHeading, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(l10n.protoSettingsHint),
            const SizedBox(height: 24),
            _settingTile(l10n.protoZoneNotifications, true, Icons.notifications_active_outlined),
            const SizedBox(height: 14),
            _settingTile(l10n.protoNearbyNotifications, true, Icons.note_add_outlined),
            const SizedBox(height: 14),
            _settingTile(l10n.protoEmergencyNotifications, false, Icons.warning_amber_outlined),
            const SizedBox(height: 32),
            ProtoButton(
              text: l10n.protoBack,
              icon: Icons.arrow_back,
              onPressed: () => ProtoNavigation.back(context),
              fullWidth: true,
              secondary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingTile(String title, bool value, IconData icon) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    // The fixed values and callbacks intentionally remain simulated.
    child: SwitchListTile(
      secondary: Icon(icon, color: kPrimaryColor),
      title: Text(title),
      value: value,
      onChanged: (_) {},
      activeThumbColor: kPrimaryColor,
    ),
  );
}
