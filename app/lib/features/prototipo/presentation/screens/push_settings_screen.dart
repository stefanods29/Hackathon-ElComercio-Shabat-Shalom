import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class PushSettingsScreen extends StatefulWidget {
  const PushSettingsScreen({super.key});

  @override
  State<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends State<PushSettingsScreen> {
  bool _zone = true;
  bool _nearby = true;
  bool _emergency = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.pushTitle), leading: const ProtoBackButton()),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(l10n.protoSettingsHeading, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text(l10n.protoSettingsHint, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 20),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _settingTile(
                        keyName: 'push-zone',
                        title: l10n.protoZoneNotifications,
                        value: _zone,
                        icon: Icons.notifications_active_outlined,
                        onChanged: (value) => setState(() => _zone = value),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _settingTile(
                        keyName: 'push-nearby',
                        title: l10n.protoNearbyNotifications,
                        value: _nearby,
                        icon: Icons.near_me_outlined,
                        onChanged: (value) => setState(() => _nearby = value),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      _settingTile(
                        keyName: 'push-emergency',
                        title: l10n.protoEmergencyNotifications,
                        value: _emergency,
                        icon: Icons.warning_amber_outlined,
                        onChanged: (value) => setState(() => _emergency = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ProtoButton(
                  key: const ValueKey<String>('push-settings-back'),
                  text: l10n.protoBack,
                  icon: Icons.arrow_back,
                  onPressed: () => ProtoNavigation.back(context),
                  fullWidth: true,
                  secondary: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingTile({
    required String keyName,
    required String title,
    required bool value,
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) => SwitchListTile.adaptive(
    key: ValueKey<String>(keyName),
    secondary: Icon(icon, color: kPrimaryColor),
    title: Text(title),
    value: value,
    onChanged: onChanged,
    activeThumbColor: kPrimaryColor,
  );
}
