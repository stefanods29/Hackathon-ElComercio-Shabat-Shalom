import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/simple_mode.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/l10n/app_localizations.dart';

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
            children: [
              ListTile(
                leading: const Icon(Icons.person),
                title: Text(user?.displayName ?? texts.unknownUser),
                subtitle: Text(texts.accountSignedIn),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.tips_and_updates),
                title: Text(texts.viewTutorial),
                onTap: () => context.push(Routes.tutorial),
              ),
              ListTile(
                leading: const Icon(Icons.accessibility_new),
                title: Text(texts.simpleModeTitle),
                subtitle: Text(texts.simpleModeSubtitle),
                trailing: Switch(
                  value: simpleModeAsync.value == true,
                  onChanged: (_) =>
                      ref.read(simpleModeProvider.notifier).toggle(),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: Text(texts.signOut),
                subtitle: Text(texts.signOutWarning),
                onTap: () => _confirmSignOut(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.phone_missed),
                title: Text(texts.lostPhone),
                subtitle: Text(texts.lostPhoneSubtitle),
                onTap: () => _confirmLostPhone(context, ref),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('$error')),
      ),
    );
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
    if (confirmed == true && context.mounted) {
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) context.go(Routes.signIn);
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
    if (confirmed == true && context.mounted) {
      await ref.read(authRepositoryProvider).signOutEverywhere();
      if (context.mounted) context.go(Routes.signIn);
    }
  }
}
