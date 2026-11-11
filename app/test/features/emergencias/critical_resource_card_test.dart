import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_resource_pages.dart';
import 'package:vecinal/l10n/app_localizations.dart';

void main() {
  final reportedAt = DateTime.utc(2026, 11, 7, 23, 58);
  final verifiedAt = DateTime.utc(2026, 11, 8);
  const sourceName = 'Fuente de prueba';
  const sourceAndDate = 'Fuente: Fuente de prueba · Verificado: 8/11/2026';

  Future<void> show(
    WidgetTester tester, {
    required DateTime Function() clock,
    ResourceVerification verification = ResourceVerification.verified,
    bool official = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clockProvider.overrideWithValue(clock)],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CriticalResourceCard(
              resource: CriticalResource(
                id: 'agua',
                kind: ResourceKind.water,
                description: 'Punto de agua de prueba',
                reportedAt: reportedAt,
                staleAfter: const Duration(minutes: 5),
                verification: verification,
                source: ResourceSource(
                  name: sourceName,
                  verifiedAt: verifiedAt,
                  official: official,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('actualiza la antigüedad y marca el recurso al llegar al umbral del servidor', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var now = reportedAt.add(const Duration(minutes: 4));
    await show(tester, clock: () => now);
    final stale = find.textContaining('confirma antes de ir');
    final warned = find.bySemanticsLabel(RegExp('Posiblemente desactualizado'));
    expect(find.text('Hace 4 minutos'), findsOneWidget);
    expect(stale, findsNothing);
    expect(warned, findsNothing);

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    // The age turns into a warning in the same pill; the screen reader hears it in full.
    expect(find.text('Hace 5 minutos · confirma antes de ir'), findsOneWidget);
    expect(stale, findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Reportado hace 5 minutos')), findsOneWidget);
    expect(warned, findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('oculta la fuente y la insignia de un recurso sin verificación', (tester) async {
    await show(tester, clock: () => verifiedAt, verification: ResourceVerification.neighbors);
    expect(find.textContaining(sourceName), findsNothing);
    expect(find.text('Fuente oficial'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final official in [false, true]) {
    testWidgets('muestra la fuente verificada y respeta oficial=$official', (tester) async {
      await show(tester, clock: () => verifiedAt, official: official);
      expect(find.text(sourceAndDate), findsOneWidget);
      expect(find.text('Fuente oficial'), official ? findsOneWidget : findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
