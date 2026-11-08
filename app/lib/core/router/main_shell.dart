import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Bottom navigation of the main sections. Each section keeps its own place, so the neighbor
/// moves between the wall, the services, the emergency dashboard and the account without
/// losing what they were looking at. Emergency is always one tap away (section 7.1).
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
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
              selectedIcon: Icon(Icons.sos, color: scheme.onPrimary),
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
