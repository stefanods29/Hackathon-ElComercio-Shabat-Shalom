import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/main_shell.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class _EmergencyHome extends Notifier<bool> {
  @override
  bool build() => false;

  void turnOn() => state = true;
}

final _emergencyHome = NotifierProvider<_EmergencyHome, bool>(_EmergencyHome.new);

void main() {
  testWidgets('al activarse el modo emergencia la app abre la pestaña Emergencia', (tester) async {
    final router = GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => MainShell(shell: shell),
          branches: [
            for (final (path, label) in [
              ('/', 'inicio'),
              ('/servicios', 'servicios'),
              ('/emergencia/tablero', 'tablero'),
              ('/cuenta', 'cuenta'),
            ])
              StatefulShellBranch(
                routes: [GoRoute(path: path, builder: (_, _) => Text(label))],
              ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final container = ProviderContainer(
      overrides: [emergencyHomeProvider.overrideWith((ref) => ref.watch(_emergencyHome))],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('inicio'), findsOneWidget);

    container.read(_emergencyHome.notifier).turnOn();
    await tester.pumpAndSettle();
    expect(find.text('tablero'), findsOneWidget);

    // Inicio stays the wall: going back to it does not bounce to Emergencia again.
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text('inicio'), findsOneWidget);
  });
}
