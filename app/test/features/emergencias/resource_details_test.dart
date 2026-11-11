import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_detail_pages.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_resource_pages.dart';
import 'package:vecinal/l10n/app_localizations.dart';

final _now = DateTime(2026, 11, 11, 12);
const _scope = EmergencyScope(accountId: 'practica', zoneId: 'zona', practice: true);

/// The share sheet of the phone: records the text instead of opening.
class _Share implements AppShare {
  final texts = <String>[];
  @override
  Future<bool> text(String text, Rect origin) async {
    texts.add(text);
    return true;
  }

  @override
  Future<bool> json(Map<String, Object?> data, Rect origin) async => true;
}

/// "Recursos cerca" in practice, with its fictitious resources and zone, and the screens it opens.
Future<_Share> _show(
  WidgetTester tester, {
  String initialLocation = Routes.emergencyResources,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final share = _Share();
  final container = ProviderContainer(
    overrides: [
      emergencyScopeProvider.overrideWithValue(_scope),
      clockProvider.overrideWithValue(() => _now),
      appShareProvider.overrideWithValue(share),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: Routes.emergencyResources, builder: (_, _) => const EmergencyResourcesPage()),
      GoRoute(
        path: Routes.emergencyResourceDetail,
        builder: (_, state) => EmergencyResourceDetailPage(resourceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.emergencyZoneDemand,
        builder: (_, state) => EmergencyZoneDemandPage(
          cell: state.pathParameters['cell']!,
          need: state.pathParameters['need']!,
        ),
      ),
      GoRoute(
        path: Routes.emergencyOffer,
        builder: (_, _) => Scaffold(appBar: AppBar(), body: const Text('ofrecer')),
      ),
      GoRoute(
        path: Routes.emergencyReportResource,
        builder: (_, state) =>
            Scaffold(appBar: AppBar(), body: Text('reportar ${state.uri.queryParameters['tipo']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
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
  return share;
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations t;
  setUpAll(() async => t = await AppLocalizations.delegate.load(const Locale('es')));

  testWidgets('tocar un recurso abre su detalle: vigencia, quién lo confirma y qué llevar', (
    tester,
  ) async {
    await _show(tester);
    await tester.tap(find.text('Local comunal'));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyResourceDetailPage), findsOneWidget);
    // Water reported 3 hours ago counts as current for 2: the detail says why to confirm.
    expect(find.text(t.emergencyStaleFor(t.emergencyHours(2))), findsOneWidget);
    expect(find.text(t.emergencyWhenReported), findsOneWidget);
    expect(find.text(t.emergencyDetailUnverified), findsOneWidget);
    expect(find.text(t.emergencyTipWater), findsOneWidget);
    expect(find.text(t.emergencyTipSafety), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _back(tester);
    await tester.tap(find.text('Colegio de la zona'));
    await tester.pumpAndSettle();
    expect(find.text(t.emergencyFreshFor(t.emergencyHours(12))), findsOneWidget);
    expect(find.textContaining('Lo verificó Municipalidad (datos de ejemplo)'), findsOneWidget);
    expect(find.text(t.emergencyTipShelter), findsOneWidget);
  });

  testWidgets('compartir un recurso de práctica avisa que los datos son ficticios', (tester) async {
    final share = await _show(tester);
    await tester.tap(find.text('Parroquia del barrio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.emergencyShareResource));
    await tester.pumpAndSettle();
    final text = share.texts.single;
    expect(text, startsWith(t.emergencySharePractice('')));
    expect(text, contains('${t.emergencyNeedFood}: Parroquia del barrio'));
    expect(text, contains(t.emergencyConfirmedNeighbors(2)));
  });

  testWidgets('un recurso que ya no está en la lista lo dice en vez de mostrar datos viejos', (
    tester,
  ) async {
    await _show(tester, initialLocation: resourceDetailRoute('no-existe'));
    expect(find.text(t.emergencyResourceGone), findsOneWidget);
  });

  testWidgets('tocar un pedido por zona abre cómo ayudar y los recursos que lo atienden', (
    tester,
  ) async {
    await _show(tester);
    await tester.tap(find.text(t.emergencyTabDemands));
    await tester.pumpAndSettle();
    final water = t.emergencyBoardDemand(6, t.emergencyBoardCategory('agua'));
    await tester.tap(find.text(water));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyZoneDemandPage), findsOneWidget);
    expect(find.text(t.emergencySector('A3')), findsWidgets);
    expect(find.text(water), findsOneWidget);
    expect(find.text(t.emergencyDemandPrivacy), findsOneWidget);
    // The water reported nearby answers this request, and opens its own detail.
    expect(find.text('Local comunal'), findsOneWidget);

    await tester.tap(find.text(t.emergencyCanHelp));
    await tester.pumpAndSettle();
    expect(find.text('ofrecer'), findsOneWidget);
    await _back(tester);

    await tester.tap(find.text(t.emergencyReportResource));
    await tester.pumpAndSettle();
    expect(find.text('reportar water'), findsOneWidget);
    await _back(tester);

    await tester.tap(find.text('Local comunal'));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyResourceDetailPage), findsOneWidget);
  });

  testWidgets('un pedido sin recursos que lo atiendan invita a reportar uno', (tester) async {
    await _show(
      tester,
      initialLocation: Routes.emergencyZoneDemand
          .replaceFirst(':cell', 'C1')
          .replaceFirst(':need', 'traslado'),
    );
    expect(find.text(t.emergencyNoNearbyForThis), findsOneWidget);
    await tester.tap(find.text(t.emergencyReportResource));
    await tester.pumpAndSettle();
    expect(find.text('reportar null'), findsOneWidget);
  });

  testWidgets('reportar desde un pedido llega con el tipo de recurso ya elegido', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyScopeProvider.overrideWithValue(_scope),
          clockProvider.overrideWithValue(() => _now),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EmergencyReportResourcePage(initialKind: ResourceKind.shelter),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.text(t.emergencyNeedShelter)), isSemantics(isSelected: true));
    expect(
      tester.getSemantics(find.text(t.emergencyNeedWater)),
      isNot(isSemantics(isSelected: true)),
    );
    semantics.dispose();
  });
}
