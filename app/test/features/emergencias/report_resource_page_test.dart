import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_resource_pages.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Dictation that hears one sentence at once, without a microphone.
class _Dictation implements CommentDictation {
  @override
  Future<bool> start(void Function(String) onWords, void Function() onFailure) async {
    onWords('Veinte bidones en el local comunal');
    return true;
  }

  @override
  Future<void> stop() async {}
}

class _Repository extends UnavailableEmergencyRepository {
  final drafts = <ResourceReportDraft>[];
  @override
  Stream<EmergencySnapshot> watch() =>
      Stream.value(const EmergencySnapshot(coverageVerified: true));
  @override
  Future<void> reportResource(ResourceReportDraft draft) async => drafts.add(draft);
}

void main() {
  late AppLocalizations t;
  setUpAll(() async => t = await AppLocalizations.delegate.load(const Locale('es')));

  Future<_Repository> show(WidgetTester tester, {required bool practice}) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/reportar'),
              child: const Text('lista'),
            ),
          ),
        ),
        GoRoute(path: '/reportar', builder: (_, _) => const EmergencyReportResourcePage()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyScopeProvider.overrideWithValue(
            EmergencyScope(accountId: 'cuenta', zoneId: 'zona', practice: practice),
          ),
          emergencyRepositoryProvider.overrideWithValue(repository),
          commentDictationProvider.overrideWithValue(_Dictation()),
          directoryOriginProvider.overrideWithValue(const GeoPoint(-12.085, -77.035)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('lista'));
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('en práctica se elige el tipo con un toque y el detalle se puede dictar', (
    tester,
  ) async {
    final repository = await show(tester, practice: true);
    expect(find.byType(DropdownButtonFormField<ResourceKind>), findsNothing);
    await tester.tap(find.text(t.emergencyNeedFood));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(t.emergencyDictation));
    await tester.pumpAndSettle();
    expect(find.text('Veinte bidones en el local comunal'), findsOneWidget);
    // While it listens, the same button stops the dictation.
    expect(find.byTooltip(t.emergencyStopDictation), findsOneWidget);
    await tester.tap(find.text(t.emergencySavePractice));
    await tester.pumpAndSettle();
    final draft = repository.drafts.single;
    expect(draft.kind, ResourceKind.food);
    expect(draft.description, 'Veinte bidones en el local comunal');
    expect(find.text(t.emergencyResourceSaved), findsOneWidget);
    expect(find.text('lista'), findsOneWidget);
  });

  testWidgets('con la cuenta real el reporte lleva tipo y cantidad, sin texto libre', (
    tester,
  ) async {
    final repository = await show(tester, practice: false);
    expect(find.text(t.emergencyNeedOther), findsNothing);
    expect(find.byTooltip(t.emergencyDictation), findsNothing);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip(t.emergencyQuantityMore));
      await tester.pump();
    }
    await tester.tap(find.byTooltip(t.emergencyQuantityLess));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, t.emergencyReportResource));
    await tester.pumpAndSettle();
    final draft = repository.drafts.single;
    expect(draft.kind, ResourceKind.water);
    expect(draft.quantity, 2);
    expect(draft.description, isEmpty);
  });
}
