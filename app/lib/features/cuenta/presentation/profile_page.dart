import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Name and trust level the neighbor shows to the zone, with shortcuts to what they published.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final practice = ref.watch(practiceModeProvider).value == true;
    final auth = ref.watch(authStateProvider).value;
    final session = ref.watch(effectiveSessionProvider);
    final user = auth is SignedIn ? auth.user : null;
    final name = practice ? session.displayName : user?.displayName ?? t.unknownUser;
    final level = practice ? session.trustLevel : user?.trustLevel ?? 0;
    return Scaffold(
      appBar: AppBar(title: Text(t.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Center(child: ProfileAvatar(name: name, radius: 44)),
          const SizedBox(height: 16),
          Text(name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_outlined,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t.profileTrustLevel(level),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.rate_review_outlined),
                  title: Text(t.profileMyReviews),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/cuenta/mis-resenas'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(t.profileEditData),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.myData),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.trending_up),
                  title: Text(t.levelsTitle),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.levels),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The neighbor's initial on a solid circle; no photo is needed to recognize the account.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.radius = 28});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      child: Text(
        initial,
        style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w700),
      ),
    );
  }
}
