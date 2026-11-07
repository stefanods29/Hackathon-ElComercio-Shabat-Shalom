import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/mapa/data/providers.dart';
import 'package:vecinal/features/mapa/domain/download_policy.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';
import 'package:vecinal/features/mapa/presentation/map_page.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/l10n/app_localizations.dart';

import 'support/fakes.dart';

Widget _mapView(BuildContext context, MapRegionDefinition definition) =>
    const ColoredBox(color: Colors.grey);

Future<void> _reveal(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 160);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  late FakeMapRegionRepository repository;
  late FakeMapConnectionMonitor monitor;

  setUp(() {
    repository = FakeMapRegionRepository();
    monitor = FakeMapConnectionMonitor();
  });
  tearDown(() async {
    await repository.close();
    await monitor.close();
  });

  Widget host({double textScale = 1, bool router = false}) => ProviderScope(
    overrides: [
      mapRegionRepositoryProvider.overrideWithValue(repository),
      mapConnectionMonitorProvider.overrideWithValue(monitor),
      offlineMapSupportedProvider.overrideWithValue(true),
      mapViewBuilderProvider.overrideWithValue(_mapView),
    ],
    child: router
        ? const VecinalApp()
        : MaterialApp(
            theme: AccessibleTheme.light(),
            locale: const Locale('es'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const MapPage(),
          ),
  );

  testWidgets('el muro ofrece acceso al mapa y el router muestra la pantalla real', (tester) async {
    await tester.pumpWidget(host(router: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mapa sin conexión'));
    await tester.pumpAndSettle();
    expect(find.byType(MapPage), findsOneWidget);
    expect(find.text('Lince y alrededores'), findsOneWidget);
    expect(find.textContaining('© OpenStreetMap contributors'), findsOneWidget);
  });

  testWidgets('muestra avance y tamaño; cancelar permite volver a descargar', (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await _reveal(tester, 'Descargar mapa de mi distrito');
    await tester.tap(find.text('Descargar mapa de mi distrito'));
    await tester.pumpAndSettle();
    repository.emit(OfflineRegionStatus.downloading, progress: 0.25, bytes: 1500000);
    await tester.pumpAndSettle();
    expect(find.text('25 % · 1,5 MB descargados'), findsOneWidget);
    await _reveal(tester, 'Cancelar descarga');
    await tester.tap(find.text('Cancelar descarga'));
    await tester.pumpAndSettle();
    expect(repository.cancellations, 1);
    expect(find.text('Descargar mapa de mi distrito'), findsOneWidget);
  });

  testWidgets('volver a entrar al mapa comprueba otra vez la región guardada', (tester) async {
    await tester.pumpWidget(host(router: true));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mapa sin conexión'));
    await tester.pumpAndSettle();
    final firstChecks = repository.refreshes;
    expect(firstChecks, greaterThan(0));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mapa sin conexión'));
    await tester.pumpAndSettle();
    expect(repository.refreshes, greaterThan(firstChecks));
  });

  testWidgets('borrar requiere confirmación y libera la región correcta', (tester) async {
    repository.emit(OfflineRegionStatus.ready, bytes: 3000000);
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await _reveal(tester, 'Borrar mapa descargado');
    await tester.tap(find.text('Borrar mapa descargado'));
    await tester.pumpAndSettle();
    expect(repository.deletions, 0);
    await tester.tap(find.text('Conservar mapa'));
    await tester.pumpAndSettle();
    expect(repository.deletions, 0);
    await tester.tap(find.text('Borrar mapa descargado'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar mapa'));
    await tester.pumpAndSettle();
    expect(repository.deletions, 1);
  });

  testWidgets('sin Wi-Fi explica la alternativa y no empieza una descarga móvil', (tester) async {
    monitor.connection = MapConnection.other;
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();
    await _reveal(tester, 'Descargar mapa de mi distrito');
    await tester.tap(find.text('Descargar mapa de mi distrito'));
    await tester.pumpAndSettle();
    expect(repository.downloads, 0);
    expect(
      find.text('Conéctate a Wi-Fi o permite usar datos móviles y vuelve a descargar.'),
      findsOneWidget,
    );
  });

  testWidgets('texto al 200 %, atribución fija y controles accesibles sin desbordes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(host(textScale: 2));
      await tester.pumpAndSettle();
      final attribution = find.textContaining('© OpenStreetMap contributors');
      expect(attribution.hitTestable(), findsOneWidget);
      await _reveal(tester, 'Descargar mapa de mi distrito');
      await tester.pumpAndSettle();
      expect(attribution.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
  });
}
