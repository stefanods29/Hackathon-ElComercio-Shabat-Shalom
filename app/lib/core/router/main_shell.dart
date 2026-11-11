import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Index of the Emergencia tab in the bottom navigation.
const emergencyTabIndex = 2;

/// Bottom navigation of the main sections. Each section keeps its own place, so the neighbor
/// moves between the wall, the services, the emergency dashboard and the account without
/// losing what they were looking at. Emergency is always one tap away (section 7.1).
///
/// When the emergency mode turns on (the button of Inicio or an active event of the zone), the
/// app opens the Emergencia tab; Inicio keeps showing the wall with a notice.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<bool>(emergencyHomeProvider, (previous, next) {
      if (next && previous != true && shell.currentIndex != emergencyTabIndex) {
        shell.goBranch(emergencyTabIndex);
      }
    });
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AccessibleTheme.hairline(scheme))),
        ),
        child: NavigationBar(
          labelPadding: const EdgeInsets.only(top: 2),
          selectedIndex: shell.currentIndex,
          // Tapping the current section again goes back to its first screen.
          onDestinationSelected: (index) =>
              shell.goBranch(index, initialLocation: index == shell.currentIndex),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: t.navHome,
              tooltip: t.wallTitle,
            ),
            NavigationDestination(
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront),
              label: t.navServices,
              tooltip: t.directoryTitle,
            ),
            NavigationDestination(
              icon: Icon(Icons.sos_outlined, color: scheme.error),
              selectedIcon: Icon(Icons.sos, color: AccessibleTheme.onAction(scheme)),
              label: t.navEmergency,
              tooltip: t.emergencyDashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: t.navAccount,
              tooltip: t.accountTitle,
            ),
          ],
        ),
      ),
    );
  }
}
