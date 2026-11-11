import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/cuenta/data/privacy_providers.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Highest trust level of a neighbor.
const maxTrustLevel = 3;

/// The name the neighbor shows: what they last saved, or else the one of the session.
String accountDisplayName(WidgetRef ref, AppLocalizations t) {
  final saved = ref.watch(privacyDataProvider).value?.displayName;
  if (saved != null) return saved;
  if (ref.watch(practiceModeProvider).value == true) {
    return ref.watch(effectiveSessionProvider).displayName;
  }
  final auth = ref.watch(authStateProvider).value;
  return auth is SignedIn ? auth.user.displayName : t.unknownUser;
}

/// The trust level of the account, or of the practice profile.
int accountTrustLevel(WidgetRef ref) {
  if (ref.watch(practiceModeProvider).value == true) {
    return ref.watch(effectiveSessionProvider).trustLevel;
  }
  final auth = ref.watch(authStateProvider).value;
  return auth is SignedIn ? auth.user.trustLevel : 0;
}

/// The name of the zone when the account data brings it.
String? accountZoneName(WidgetRef ref) {
  final zone = ref.watch(privacyDataProvider).value?.values['zona'];
  return zone is String && zone.isNotEmpty ? zone : null;
}

String levelName(AppLocalizations t, int level) => switch (level) {
  0 => t.levelName0,
  1 => t.levelName1,
  2 => t.levelName2,
  _ => t.levelName3,
};

String levelAbilities(AppLocalizations t, int level) => switch (level) {
  0 => t.levelCan0,
  1 => t.levelCan1,
  2 => t.levelCan2,
  _ => t.levelCan3,
};

/// How to reach the next level; null at the top one.
String? levelNextStep(AppLocalizations t, int level) => switch (level) {
  0 => t.levelNext0,
  1 => t.levelNext1,
  2 => t.levelNext2,
  _ => null,
};

/// Asks before an action that cannot be undone from the screen. The button says what it does.
Future<bool> confirmAccountAction(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final t = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(t.cancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(dialog, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Shows a message at once: an older one in the queue would arrive late.
void accountMessage(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));

class AccountSectionTitle extends StatelessWidget {
  const AccountSectionTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

/// A group of options on a soft white surface.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(children: children),
    ),
  );
}

/// The round icon of an option: red only for what cannot be undone or for emergencies.
class AccountIcon extends StatelessWidget {
  const AccountIcon({super.key, required this.icon, this.destructive = false});
  final IconData icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    // In dark the circles stay neutral and only the icon carries color: fewer tinted blocks.
    final background = destructive
        ? scheme.errorContainer
        : dark
        ? scheme.surfaceContainerHigh
        : scheme.primaryContainer;
    final foreground = destructive
        ? scheme.onErrorContainer
        : dark
        ? scheme.primary
        : scheme.onPrimaryContainer;
    return ExcludeSemantics(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: foreground, size: 22),
      ),
    );
  }
}

class AccountItem extends StatelessWidget {
  const AccountItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: AccountIcon(icon: icon, destructive: destructive),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
      onTap: onTap,
    );
  }
}

/// An option that turns on and off: the whole row is the switch.
class AccountSwitchItem extends StatelessWidget {
  const AccountSwitchItem({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    secondary: AccountIcon(icon: icon),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: subtitle == null ? null : Text(subtitle!),
    value: value,
    onChanged: onChanged,
  );
}

/// The four trust levels as a bar: how far the neighbor has come at a glance.
class TrustLevelMeter extends StatelessWidget {
  const TrustLevelMeter({super.key, required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: t.accountLevelSubtitle(level),
      excludeSemantics: true,
      child: Row(
        spacing: 6,
        children: [
          for (var step = 0; step <= maxTrustLevel; step++)
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: step <= level ? scheme.primary : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
