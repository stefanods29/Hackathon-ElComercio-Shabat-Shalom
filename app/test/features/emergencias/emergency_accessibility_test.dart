import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/core/ui/simple_mode.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_contacts_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_dashboard_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_resource_pages.dart';
import 'package:vecinal/features/emergencias/presentation/help_request_pages.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Phase 2, Lot D 4.2 (automated part): every screen of emergency mode with large text, simple
/// mode, light and dark themes, minimum tap targets with labels, text contrast and the screen
/// reader order. The goldens at 200 % let a review see the layout without a phone.
const _zone = '01970000-0000-7000-8000-000000000001';
const _requestId = '01970000-0000-7000-8000-00000000a001';
final _now = DateTime.utc(2026, 11, 8, 15);
const _scope = EmergencyScope(accountId: 'cuenta', zoneId: _zone, practice: true);

/// A snapshot with coverage, a request on the way and resources, without timers or network.
class _Repository implements EmergencyRepository {
  @override
  Stream<EmergencySnapshot> watch() => Stream.value(
    EmergencySnapshot(
      coverageVerified: true,
      activeEvent: true,
      updatedAt: _now,
      requests: [
        OwnHelpRequest(
          id: _requestId,
          idempotencyKey: 'clave',
          need: EmergencyNeed.water,
          description: 'Pedido ficticio',
          locationLabel: 'Frente al parque',
          approximateLocation: const GeoPoint(-12.085, -77.035),
          createdAt: _now.subtract(const Duration(minutes: 40)),
          sentAt: _now.subtract(const Duration(minutes: 39)),
          history: [
            RequestHistoryEntry(
              status: HelpRequestStatus.local,
              at: _now.subtract(const Duration(minutes: 40)),
            ),
            RequestHistoryEntry(
              status: HelpRequestStatus.sent,
              at: _now.subtract(const Duration(minutes: 39)),
            ),
            RequestHistoryEntry(
              status: HelpRequestStatus.onTheWay,
              at: _now.subtract(const Duration(minutes: 10)),
            ),
          ],
          canConfirmAttendance: true,
        ),
      ],
      resources: [
        CriticalResource(
          id: 'recurso-agua',
          kind: ResourceKind.water,
          description: 'Agua en el local comunal',
          reportedAt: _now.subtract(const Duration(hours: 3)),
          confirmations: 2,
          verification: ResourceVerification.neighbors,
        ),
        CriticalResource(
          id: 'recurso-albergue',
          kind: ResourceKind.shelter,
          description: 'Albergue municipal',
          reportedAt: _now.subtract(const Duration(minutes: 20)),
          verification: ResourceVerification.verified,
          source: ResourceSource(
            name: 'Municipalidad (ficticia)',
            verifiedAt: _now,
            official: true,
          ),
        ),
      ],
    ),
  );

  @override
  Future<OwnHelpRequest> saveRequest(HelpRequestDraft draft) => throw UnimplementedError();
  @override
  Future<void> confirmAttendance(String requestId) async {}
  @override
  Future<void> saveOffer(HelpOffer offer) async {}
  @override
  Future<void> reportResource(ResourceReportDraft draft) async {}
}

/// The default text of `flutter test` is drawn the same on macOS and Linux, but antialiasing may
/// differ by a few pixels between the two: up to 1 % passes.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= 0.01) return true;
    throw FlutterError(await generateFailureOutput(result, golden, basedir));
  }
}

final _screens = <String, Widget Function()>{
  'tablero': () => const EmergencyDashboardPage(),
  'necesidad': () => const EmergencyNeedsPage(),
  'formulario': () => const HelpRequestFormPage(need: EmergencyNeed.water),
  'pedido': () => const OwnHelpRequestPage(requestId: _requestId),
  'recursos': () => const EmergencyResourcesPage(),
  'contactos': () => const EmergencyContactsPage(),
};

Future<void> _show(
  WidgetTester tester,
  Widget screen, {
  double textScale = 1,
  Brightness brightness = Brightness.light,
  bool simpleMode = false,
}) async {
  SharedPreferences.setMockInitialValues({'simple_mode': simpleMode});
  // A tall surface builds the whole list, so every element is checked and drawn.
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        emergencyScopeProvider.overrideWithValue(_scope),
        emergencyRepositoryProvider.overrideWithValue(_Repository()),
        clockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AccessibleTheme.light(),
        darkTheme: AccessibleTheme.dark(),
        themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _readingOrder(WidgetTester tester) => [
  for (final node in tester.semantics.simulatedAccessibilityTraversal())
    if (node.label.isNotEmpty) node.label,
];

void main() {
  late AppLocalizations t;
  setUpAll(() async {
    t = await AppLocalizations.delegate.load(const Locale('es'));
    final previous = goldenFileComparator as LocalFileComparator;
    goldenFileComparator = _TolerantComparator(
      previous.basedir.resolve('emergency_accessibility_test.dart'),
    );
  });

  for (final MapEntry(key: name, value: screen) in _screens.entries) {
    group('pantalla $name', () {
      testWidgets('con texto al 200 % no se desborda y cada botón es grande y tiene nombre', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _show(tester, screen(), textScale: 2);
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });

      for (final brightness in Brightness.values) {
        testWidgets('el texto cumple el contraste en tema ${brightness.name}', (tester) async {
          final semantics = tester.ensureSemantics();
          await _show(tester, screen(), brightness: brightness);
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        });
      }

      testWidgets('el modo sencillo agranda el texto sin desbordes', (tester) async {
        await _show(tester, screen(), simpleMode: true);
        expect(tester.takeException(), isNull);
        final scaler = MediaQuery.textScalerOf(tester.element(find.byType(ListView).first));
        expect(scaler.scale(10), greaterThan(10));
      });

      testWidgets('se ve igual que su referencia con texto al 200 %', (tester) async {
        await _show(tester, screen(), textScale: 2);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/emergencia_${name}_200.png'),
        );
      });
    });
  }

  testWidgets('el lector de pantalla recorre el tablero en orden: título, ayuda y alternativas', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _show(tester, const EmergencyDashboardPage());
    final order = _readingOrder(tester);
    int at(String text) => order.indexWhere((label) => label.contains(text));
    expect(at(t.emergencyDashboard), 0);
    expect(at(t.emergencyNeedHelp), greaterThan(at(t.emergencyDashboard)));
    expect(at(t.emergencyLifeRisk), greaterThan(-1));
    semantics.dispose();
  });

  testWidgets('en el pedido propio el estado se lee antes que las alternativas', (tester) async {
    final semantics = tester.ensureSemantics();
    await _show(tester, const OwnHelpRequestPage(requestId: _requestId));
    final order = _readingOrder(tester);
    int at(String text) => order.indexWhere((label) => label.contains(text));
    expect(at(t.emergencyRequestOnTheWay), greaterThan(-1));
    expect(at(t.emergencyLifeRisk), greaterThan(at(t.emergencyRequestOnTheWay)));
    semantics.dispose();
  });

  testWidgets('el modo sencillo queda guardado como preferencia', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(simpleModeProvider.notifier).set(true);
    expect(container.read(simpleModeProvider).value, isTrue);
    expect((await SharedPreferences.getInstance()).getBool('simple_mode'), isTrue);
  });
}
