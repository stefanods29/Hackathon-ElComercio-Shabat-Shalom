import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/session/inactivity_guard.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/features/avisos_urgentes/data/urgent_notices_providers.dart';
import 'package:vecinal_consola/features/avisos_urgentes/presentation/urgent_notices_banner.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Frame of the signed-in console: header, navigation by role, banners and the current page.
///
/// Keyboard order is explicit: header, then navigation, then the page (each region is a group).
class ConsoleShell extends ConsumerWidget {
  const ConsoleShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  static const _wideLayout = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(sessionProvider);
    // Signed out: the router is already on its way to the sign-in page.
    if (session is! SignedIn) return const SizedBox.shrink();
    final user = session.user;
    final sections = ConsoleSection.values.where(user.canOpen).toList(growable: false);
    final pending = ref.watch(pendingUrgentNoticesProvider).value?.length ?? 0;
    final wide = MediaQuery.sizeOf(context).width >= _wideLayout;
    final scheme = Theme.of(context).colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.demo) const _DemoStrip(),
        const UrgentNoticesBanner(),
        Expanded(child: child),
      ],
    );
    final navigation = _SectionNavigation(
      sections: sections,
      current: sectionOf(location),
      closeDrawerOnOpen: !wide,
    );

    final Widget page;
    if (wide) {
      page = Scaffold(
        body: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: FocusTraversalGroup(child: _Header(user: user)),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: FocusTraversalGroup(
                        child: SizedBox(
                          width: 264,
                          child: Material(color: scheme.surfaceContainerLow, child: navigation),
                        ),
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(3),
                        child: FocusTraversalGroup(child: content),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      page = Scaffold(
        appBar: AppBar(
          title: Text(l10n.consoleTitle),
          actions: [
            IconButton(
              tooltip: l10n.signOut,
              onPressed: () => ref.read(sessionProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        drawer: Drawer(child: SafeArea(child: navigation)),
        body: content,
      );
    }

    return Title(
      title: pending > 0 ? l10n.titleWithNotices(pending) : l10n.consoleTitle,
      color: scheme.primary,
      child: InactivityGuard(child: page),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.user});

  final Operator user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final roles = user.roles.map((role) => roleLabel(l10n, role)).join(' · ');
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Semantics(header: true, child: Text(l10n.consoleTitle, style: textTheme.titleLarge)),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.signedInAs(user.displayName, roles), style: textTheme.bodyLarge),
                OutlinedButton.icon(
                  onPressed: () => ref.read(sessionProvider.notifier).signOut(),
                  icon: const Icon(Icons.logout),
                  label: Text(l10n.signOut),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionNavigation extends StatelessWidget {
  const _SectionNavigation({
    required this.sections,
    required this.current,
    required this.closeDrawerOnOpen,
  });

  final List<ConsoleSection> sections;
  final ConsoleSection? current;
  final bool closeDrawerOnOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: l10n.navigationLabel,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        children: [
          for (final section in sections)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: Icon(sectionIcon(section)),
                title: Text(sectionLabel(l10n, section)),
                selected: section == current,
                onTap: () {
                  if (closeDrawerOnOpen) Scaffold.maybeOf(context)?.closeDrawer();
                  context.go(pathOf(section));
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Fixed strip of `CONSOLE_DATA=demo`: no seeded number can pass for a real one.
class _DemoStrip extends StatelessWidget {
  const _DemoStrip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.science_outlined, color: scheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.demoStrip,
                style: TextStyle(color: scheme.onTertiaryContainer, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
