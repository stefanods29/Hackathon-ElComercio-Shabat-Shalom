import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
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

/// Shared between the home tab and account route. Account actions remain simulated.
class AccountContent extends StatefulWidget {
  const AccountContent({super.key});

  @override
  State<AccountContent> createState() => _AccountContentState();
}

class _AccountContentState extends State<AccountContent> {
  bool _simpleMode = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: kAvatarColor,
                        child: Icon(Icons.person_outline, size: 30, color: kPrimaryColor),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Beto', style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            Text(l10n.protoDemoZone, style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: kTextSecondaryColor),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      key: const ValueKey<String>('account-simple-mode'),
                      value: _simpleMode,
                      onChanged: (value) => setState(() => _simpleMode = value),
                      secondary: const Icon(Icons.accessibility_new_outlined),
                      title: Text(l10n.simpleModeTitle),
                      subtitle: Text(l10n.simpleModeSubtitle),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      minTileHeight: 64,
                      leading: const Icon(Icons.school_outlined),
                      title: Text(l10n.viewTutorial),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => ProtoNavigation.open(context, ProtoRoutes.tutorial),
                    ),
                    ListTile(
                      minTileHeight: 64,
                      leading: const Icon(Icons.notifications_outlined),
                      title: Text(l10n.pushTitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => ProtoNavigation.open(context, ProtoRoutes.pushSettings),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  minTileHeight: 72,
                  leading: const Icon(Icons.warning_amber_outlined, color: kErrorColor),
                  title: Text(l10n.protoEmergency),
                  subtitle: Text(l10n.connectsNeighbors),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => ProtoNavigation.open(context, ProtoRoutes.emergency),
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                key: const ValueKey<String>('account-lost-phone'),
                onPressed: () {},
                icon: const Icon(Icons.phone_disabled_outlined),
                label: Text(l10n.lostPhone),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
