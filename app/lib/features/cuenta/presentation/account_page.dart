import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/theme_mode.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/core/ui/simple_mode.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/presentation/account_ui.dart';
import 'package:vecinal/features/cuenta/presentation/profile_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
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
      data: (_) {
        final level = accountTrustLevel(ref);
        return Scaffold(
          appBar: AppBar(title: Text(texts.accountTitle)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _ProfileCard(
                name: accountDisplayName(ref, texts),
                level: level,
                action: texts.profileOpen,
                onTap: () => context.push(Routes.profile),
              ),
              const SizedBox(height: 12),
              AccountSectionTitle(texts.sectionEmergency),
              AccountSection(
                children: [
                  AccountItem(
                    icon: Icons.contact_phone_outlined,
                    title: texts.emergencyContacts,
                    onTap: () => context.push(Routes.emergencyContacts),
                  ),
                  AccountItem(
                    icon: Icons.emergency_outlined,
                    title: texts.emergencyGoToDashboard,
                    destructive: true,
                    onTap: () => context.go(Routes.emergencyDashboard),
                  ),
                ],
              ),
              AccountSectionTitle(texts.sectionAccount),
              AccountSection(
                children: [
                  AccountItem(
                    icon: Icons.privacy_tip_outlined,
                    title: texts.privacyTitle,
                    subtitle: texts.accountMyDataSubtitle,
                    onTap: () => context.push(Routes.myData),
                  ),
                  AccountItem(
                    icon: Icons.verified_outlined,
                    title: texts.levelsTitle,
                    subtitle: texts.accountLevelSubtitle(level),
                    onTap: () => context.push(Routes.levels),
                  ),
                  AccountItem(
                    icon: Icons.location_on_outlined,
                    title: texts.changeZone,
                    subtitle: accountZoneName(ref),
                    onTap: () => context.push(Routes.changeZone),
                  ),
                  AccountItem(
                    icon: Icons.photo_library_outlined,
                    title: texts.photosTitle,
                    onTap: () => context.push(Routes.photos),
                  ),
                ],
              ),
              AccountSectionTitle(texts.settingsTitle),
              AccountSection(
                children: [
                  const _ThemePicker(),
                  AccountSwitchItem(
                    icon: Icons.accessibility_new,
                    title: texts.simpleModeTitle,
                    subtitle: texts.simpleModeSubtitle,
                    value: simpleModeAsync.value == true,
                    onChanged: (_) => ref.read(simpleModeProvider.notifier).toggle(),
                  ),
                  AccountSwitchItem(
                    icon: Icons.image_outlined,
                    title: texts.emergencyImages,
                    subtitle: texts.emergencyImagesHelp,
                    value: ref.watch(imagesEnabledProvider),
                    onChanged: (value) => ref.read(imagesEnabledProvider.notifier).set(value),
                  ),
                  AccountItem(
                    icon: Icons.notifications_outlined,
                    title: texts.pushTitle,
                    onTap: () => context.push(Routes.pushSettings),
                  ),
                  AccountItem(
                    icon: Icons.tips_and_updates_outlined,
                    title: texts.viewTutorial,
                    onTap: () => context.push(Routes.tutorial),
                  ),
                ],
              ),
              AccountSectionTitle(texts.sectionSession),
              AccountSection(
                children: [
                  AccountItem(
                    icon: Icons.logout,
                    title: texts.signOut,
                    subtitle: texts.signOutWarning,
                    onTap: () => _confirmSignOut(context, ref),
                  ),
                  AccountItem(
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
      error: (_, _) => Scaffold(
        appBar: AppBar(title: Text(texts.accountTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(texts.accountLoadFailed, textAlign: TextAlign.center),
          ),
        ),
      ),
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
    final texts = AppLocalizations.of(context);
    final confirmed = await confirmAccountAction(
      context,
      title: texts.signOutConfirmTitle,
      body: texts.signOutConfirmBody,
      action: texts.signOut,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    if (ref.read(practiceModeProvider).value != false) {
      accountMessage(context, texts.practiceSignOutDone);
      return;
    }
    try {
      await _unregisterPush(ref);
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go(Routes.signIn);
    } catch (_) {
      if (context.mounted) accountMessage(context, texts.signOutFailed);
    }
  }

  Future<void> _confirmLostPhone(BuildContext context, WidgetRef ref) async {
    final texts = AppLocalizations.of(context);
    final confirmed = await confirmAccountAction(
      context,
      title: texts.lostPhoneConfirmTitle,
      body: texts.lostPhoneConfirmBody,
      action: texts.lostPhoneConfirmAction,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    if (ref.read(practiceModeProvider).value != false) {
      accountMessage(context, texts.practiceLostPhoneDone);
      return;
    }
    try {
      await _unregisterPush(ref);
      await ref.read(authRepositoryProvider).signOutEverywhere();
      if (context.mounted) context.go(Routes.signIn);
    } catch (_) {
      if (context.mounted) accountMessage(context, texts.lostPhoneFailed);
    }
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.level,
    required this.action,
    required this.onTap,
  });
  final String name;
  final int level;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
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
              MyProfileAvatar(name: name),
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
                      t.profileTrustLevel(level),
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

/// Light, dark or automatic as three tiles: an icon over the word, so no word is ever cut.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final selected = ref.watch(themeModeProvider);
    final stacked = emergencyLargeText(context);
    final options = [
      for (final (mode, icon, label) in [
        (ThemeMode.system, Icons.brightness_auto_outlined, texts.themeSystem),
        (ThemeMode.light, Icons.light_mode_outlined, texts.themeLight),
        (ThemeMode.dark, Icons.dark_mode_outlined, texts.themeDark),
      ])
        _ThemeOption(
          icon: icon,
          label: label,
          selected: selected == mode,
          horizontal: stacked,
          onPressed: () => ref.read(themeModeProvider.notifier).set(mode),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              const AccountIcon(icon: Icons.palette_outlined),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  texts.themeTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
              ),
            ],
          ),
          if (stacked)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: options)
          else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 8,
                children: [for (final option in options) Expanded(child: option)],
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.horizontal,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final bool horizontal;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    const style = TextStyle(fontSize: 15, fontWeight: FontWeight.w700);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 72),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        elevation: 0,
        backgroundColor: selected ? scheme.primaryContainer : scheme.surfaceContainer,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? scheme.primary : Colors.transparent, width: 2),
        ),
      ),
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: horizontal
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 10,
                children: [
                  Icon(icon, size: 24),
                  Flexible(child: Text(label, style: style)),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 6,
                children: [
                  Icon(icon, size: 24),
                  // On a narrow phone the word shrinks a little instead of breaking in two.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, maxLines: 1, softWrap: false, style: style),
                  ),
                ],
              ),
      ),
    );
  }
}
