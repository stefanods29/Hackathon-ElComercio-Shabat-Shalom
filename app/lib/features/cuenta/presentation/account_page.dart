import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/theme_mode.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/core/ui/simple_mode.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/cuenta/presentation/profile_page.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Longest wait for the push unregistration before signing out anyway.
const _pushSignOutLimit = Duration(seconds: 5);

/// Pantalla "Mi cuenta" (/cuenta).
class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final authStateAsync = ref.watch(authStateProvider);
    final simpleModeAsync = ref.watch(simpleModeProvider);

    return authStateAsync.when(
      data: (authState) {
        final user = switch (authState) {
          SignedIn() => authState.user,
          _ => null,
        };

        return Scaffold(
          appBar: AppBar(title: Text(texts.accountTitle)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _ProfileCard(
                name: ref.watch(practiceModeProvider).value == true
                    ? ref.watch(effectiveSessionProvider).displayName
                    : user?.displayName ?? texts.unknownUser,
                subtitle: texts.accountSignedIn,
                action: texts.profileOpen,
                onTap: () => context.push(Routes.profile),
              ),
              const SizedBox(height: 12),
              _SectionTitle(texts.sectionEmergency),
              _Section(
                children: [
                  _Item(
                    icon: Icons.contact_phone_outlined,
                    title: texts.emergencyContacts,
                    onTap: () => context.push(Routes.emergencyContacts),
                  ),
                  _Item(
                    icon: Icons.emergency_outlined,
                    title: texts.emergencyDashboard,
                    destructive: true,
                    onTap: () => context.go(Routes.emergencyDashboard),
                  ),
                ],
              ),
              _SectionTitle(texts.sectionAccount),
              _Section(
                children: [
                  _Item(
                    icon: Icons.privacy_tip_outlined,
                    title: texts.privacyTitle,
                    onTap: () => context.push(Routes.myData),
                  ),
                  _Item(
                    icon: Icons.verified_outlined,
                    title: texts.levelsTitle,
                    onTap: () => context.push(Routes.levels),
                  ),
                  _Item(
                    icon: Icons.location_on_outlined,
                    title: texts.changeZone,
                    onTap: () => context.push(Routes.changeZone),
                  ),
                  _Item(
                    icon: Icons.notifications_outlined,
                    title: texts.pushTitle,
                    onTap: () => context.push(Routes.pushSettings),
                  ),
                  _Item(
                    icon: Icons.photo_library_outlined,
                    title: texts.photosTitle,
                    onTap: () => context.push(Routes.photos),
                  ),
                  _Item(
                    icon: Icons.tips_and_updates,
                    title: texts.viewTutorial,
                    onTap: () => context.push(Routes.tutorial),
                  ),
                  _Item(
                    icon: Icons.accessibility_new,
                    title: texts.simpleModeTitle,
                    subtitle: texts.simpleModeSubtitle,
                    trailing: Switch(
                      value: simpleModeAsync.value == true,
                      onChanged: (_) => ref.read(simpleModeProvider.notifier).toggle(),
                    ),
                  ),
                ],
              ),
              _SectionTitle(texts.settingsTitle),
              _Section(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 12,
                      children: [
                        Text(
                          texts.themeTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: const Icon(Icons.brightness_auto_outlined),
                              label: Text(texts.themeSystem),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: const Icon(Icons.light_mode_outlined),
                              label: Text(texts.themeLight),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: const Icon(Icons.dark_mode_outlined),
                              label: Text(texts.themeDark),
                            ),
                          ],
                          selected: {ref.watch(themeModeProvider)},
                          onSelectionChanged: (value) =>
                              ref.read(themeModeProvider.notifier).set(value.first),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    secondary: const Icon(Icons.image_outlined),
                    title: Text(
                      texts.emergencyImages,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(texts.emergencyImagesHelp),
                    value: ref.watch(imagesEnabledProvider),
                    onChanged: (value) => ref.read(imagesEnabledProvider.notifier).set(value),
                  ),
                ],
              ),
              _SectionTitle(texts.sectionSession),
              _Section(
                children: [
                  _Item(
                    icon: Icons.logout,
                    title: texts.signOut,
                    subtitle: texts.signOutWarning,
                    onTap: () => _confirmSignOut(context, ref),
                  ),
                  _Item(
                    icon: Icons.phone_missed,
                    title: texts.lostPhone,
                    subtitle: texts.lostPhoneSubtitle,
                    destructive: true,
                    onTap: () => _confirmLostPhone(context, ref),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
    );
  }

  /// Unregisters the push token while the session is still valid (Lot A, task 2.5).
  Future<void> _unregisterPush(WidgetRef ref) async {
    try {
      await ref.read(pushControllerProvider.notifier).signOut().timeout(_pushSignOutLimit);
    } catch (_) {
      // Signing out keeps working offline; the next sign-in invalidates this installation.
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).signOutConfirmTitle),
        content: Text(AppLocalizations.of(context).signOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted && ref.read(practiceModeProvider).value != false) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).practiceSignOutDone)));
      return;
    }
    if (confirmed == true && context.mounted && ref.read(practiceModeProvider).value == false) {
      try {
        await _unregisterPush(ref);
        await ref.read(authRepositoryProvider).signOut();
        if (context.mounted) context.go(Routes.signIn);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo terminar el borrado local. Intenta de nuevo.'),
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmLostPhone(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).lostPhoneConfirmTitle),
        content: Text(AppLocalizations.of(context).lostPhoneConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context).confirm),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted && ref.read(practiceModeProvider).value != false) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).practiceLostPhoneDone)));
      return;
    }
    if (confirmed == true && context.mounted && ref.read(practiceModeProvider).value == false) {
      try {
        await _unregisterPush(ref);
        await ref.read(authRepositoryProvider).signOutEverywhere();
        if (context.mounted) context.go(Routes.signIn);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudieron cerrar las otras sesiones. Revisa tu conexión.'),
            ),
          );
        }
      }
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.subtitle,
    required this.action,
    required this.onTap,
  });
  final String name;
  final String subtitle;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
          child: Row(
            children: [
              ProfileAvatar(name: name),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      action,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// A group of options on a soft white surface.
class _Section extends StatelessWidget {
  const _Section({required this.children});
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

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
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
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: Icon(icon, color: foreground, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (onTap == null ? null : Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)),
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
