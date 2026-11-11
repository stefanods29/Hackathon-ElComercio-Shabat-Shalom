import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/mode/app_mode.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/emergencias/data/emergency_contacts.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/emergency_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_dashboard_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/features/emergencias/presentation/help_request_pages.dart';
import 'package:vecinal/features/emergencias/public_emergency_directory.dart';
import 'package:vecinal/features/solidaridad/presentation/wall_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

final _now = DateTime.utc(2026, 11, 8, 12);
const _scope = EmergencyScope(accountId: 'test-account', zoneId: 'test-zone', practice: false);
const _point = GeoPoint(0, 0);

OwnHelpRequest _request(HelpRequestStatus status, {bool canConfirm = false}) => OwnHelpRequest(
  id: 'test-request',
  idempotencyKey: 'test-key',
  need: EmergencyNeed.water,
  description: 'Pedido ficticio para una prueba',
  locationLabel: 'Punto ficticio',
  approximateLocation: _point,
  createdAt: _now.subtract(const Duration(minutes: 15)),
  sentAt: status == HelpRequestStatus.local ? null : _now.subtract(const Duration(minutes: 10)),
  history: [RequestHistoryEntry(status: status, at: _now)],
  reason: switch (status) {
    HelpRequestStatus.referred || HelpRequestStatus.closedUnattended => 'Motivo ficticio',
    _ => null,
  },
  nextStep: switch (status) {
    HelpRequestStatus.referred || HelpRequestStatus.closedUnattended => 'Paso siguiente ficticio',
    _ => null,
  },
  canConfirmAttendance: canConfirm,
);

class _Repository extends UnavailableEmergencyRepository {
  _Repository(this.snapshot);
  EmergencySnapshot snapshot;
  final drafts = <HelpRequestDraft>[];
  final _changes = StreamController<EmergencySnapshot>.broadcast();
  Completer<void>? pending;
  bool failNext = false;

  @override
  Stream<EmergencySnapshot> watch() async* {
    yield snapshot;
    yield* _changes.stream;
  }

  @override
  Future<OwnHelpRequest> saveRequest(HelpRequestDraft draft) async {
    drafts.add(draft);
    if (pending != null) await pending!.future;
    if (failNext) {
      failNext = false;
      throw StateError('Simulated failure');
    }
    final existing = snapshot.requests.where((r) => r.idempotencyKey == draft.idempotencyKey);
    if (existing.isNotEmpty) return existing.first;
    final request = OwnHelpRequest(
      id: draft.id,
      idempotencyKey: draft.idempotencyKey,
      need: draft.need,
      description: draft.description,
      locationLabel: draft.locationLabel,
      approximateLocation: draft.approximateLocation,
      createdAt: _now,
      history: [RequestHistoryEntry(status: HelpRequestStatus.local, at: _now)],
    );
    snapshot = EmergencySnapshot(coverageVerified: true, requests: [...snapshot.requests, request]);
    _changes.add(snapshot);
    return request;
  }

  Future<void> close() => _changes.close();
}

class _SmsSpy implements SmsComposer {
  int calls = 0;
  @override
  Future<bool> compose({required String recipient, required String body}) async {
    calls++;
    return true;
  }
}

Future<ProviderContainer> _show(
  WidgetTester tester, {
  EmergencyRepository? repository,
  Widget page = const EmergencyDashboardPage(),
  bool practice = false,
  bool connected = true,
  _SmsSpy? sms,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1000, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sync = FakeSyncService(SyncStatus(connected: connected));
  addTearDown(sync.close);
  final container = ProviderContainer(
    overrides: [
      emergencyScopeProvider.overrideWithValue(
        practice
            ? const EmergencyScope(accountId: 'practice', zoneId: 'test-zone', practice: true)
            : _scope,
      ),
      if (repository != null) emergencyRepositoryProvider.overrideWithValue(repository),
      clockProvider.overrideWithValue(() => _now),
      directoryOriginProvider.overrideWithValue(_point),
      syncServiceProvider.overrideWithValue(sync),
      if (sms != null) smsComposerProvider.overrideWithValue(sms),
      publicEmergencyDirectoryProvider.overrideWith(
        (ref) => Stream.value(
          PublicEmergencyDirectory(
            entries: [
              for (final number in ['116', '105', '106'])
                PublicEmergencyEntry(
                  id: 'official-$number',
                  kind: PublicEmergencyKind.phone,
                  label: 'Servicio $number',
                  sourceName: 'Fuente de prueba',
                  verifiedAt: _now,
                  number: number,
                ),
            ],
            district: 'Zona ficticia',
            version: 1,
            generatedAt: _now,
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, _) => page),
      GoRoute(path: Routes.emergencyDashboard, builder: (_, _) => const EmergencyDashboardPage()),
      GoRoute(path: Routes.emergencyNeeds, builder: (_, _) => const EmergencyNeedsPage()),
      GoRoute(
        path: Routes.emergencyRequestForm,
        builder: (_, state) =>
            HelpRequestFormPage(need: EmergencyNeed.values.byName(state.pathParameters['need']!)),
      ),
      GoRoute(
        path: Routes.emergencyRequest,
        builder: (_, state) => OwnHelpRequestPage(requestId: state.pathParameters['id']!),
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
  return container;
}

/// The red strip with a call button for each official number stays on screen in every state.
void _expectAlternatives(AppLocalizations t) {
  expect(find.byType(EmergencyAlternatives), findsOneWidget);
  expect(find.textContaining('Si hay riesgo para la vida'), findsOneWidget);
  expect(find.byType(EmergencyCallButton), findsNWidgets(3));
  for (final number in ['116', '105', '106']) {
    expect(find.text(number), findsOneWidget);
  }
}

void main() {
  late AppLocalizations t;
  setUpAll(() async => t = await AppLocalizations.delegate.load(const Locale('es')));

  testWidgets('sin cobertura mantiene alternativas y deshabilita pedir u ofrecer ayuda', (
    tester,
  ) async {
    final repository = _Repository(const EmergencySnapshot());
    addTearDown(repository.close);
    await _show(tester, repository: repository);
    expect(find.text(t.emergencyNoCoverage), findsOneWidget);
    _expectAlternatives(t);
    for (final label in [t.emergencyNeedHelp, t.emergencyCanHelp]) {
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, label)).onPressed,
        isNull,
      );
    }
  });

  testWidgets('un evento activo deja el muro en Inicio con un aviso y desactiva imágenes', (
    tester,
  ) async {
    final repository = _Repository(
      const EmergencySnapshot(coverageVerified: true, activeEvent: true),
    );
    addTearDown(repository.close);
    final container = await _show(tester, repository: repository, page: const WallPage());
    expect(container.read(emergencyHomeProvider), isTrue);
    // Inicio and Emergencia are different screens: the wall stays and leads to the dashboard.
    expect(find.byType(EmergencyDashboardPage), findsNothing);
    expect(find.text(t.emergencyModeOnTitle), findsOneWidget);
    expect(container.read(imagesEnabledProvider), isFalse);
    await tester.tap(find.text(t.emergencyGoToDashboard));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyDashboardPage), findsOneWidget);
  });

  testWidgets('los botones de llamada se apilan cuando el nombre no cabe al lado', (tester) async {
    Future<bool> stackedAt(double width, double textScale) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: EmergencyCallButtons(
                    buttons: [
                      for (final (number, name) in [
                        ('116', 'Bomberos'),
                        ('105', 'Policía'),
                        ('106', 'SAMU'),
                      ])
                        (number, name, 'Llamar a $name, $number', () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      return tester
          .widgetList<EmergencyCallButton>(find.byType(EmergencyCallButton))
          .every((button) => button.horizontal);
    }

    // The width of the strip on a 414 dp phone, then on a 360 dp one and with larger text.
    expect(await stackedAt(342, 1), isFalse);
    expect(await stackedAt(288, 1), isTrue);
    expect(await stackedAt(342, 1.3), isTrue);
  });

  testWidgets(
    'activar desde el inicio abre el tablero, avisa que no notifica a nadie e impide encender '
    'imágenes',
    (tester) async {
      final repository = _Repository(const EmergencySnapshot(coverageVerified: true));
      addTearDown(repository.close);
      final container = await _show(tester, repository: repository, page: const WallPage());
      expect(container.read(imagesEnabledProvider), isTrue);
      await tester.tap(find.widgetWithText(FilledButton, t.activateLocalEmergency));
      await tester.pumpAndSettle();
      expect(container.read(appModeProvider), AppMode.emergency);
      expect(find.byType(EmergencyDashboardPage), findsOneWidget);
      expect(find.text(t.emergencyModeActivated), findsOneWidget);
      expect(container.read(imagesEnabledProvider), isFalse);
      final saver = find.widgetWithText(SwitchListTile, t.emergencyDataSaver);
      expect(tester.widget<SwitchListTile>(saver).value, isTrue);
      await tester.tap(saver);
      await tester.pumpAndSettle();
      expect(container.read(imagesEnabledProvider), isFalse);
      expect(tester.widget<SwitchListTile>(saver).value, isTrue);
      expect(find.text(t.emergencyImagesLocked), findsOneWidget);
    },
  );

  testWidgets('el directorio abre con los números y no repite botones para activar el modo', (
    tester,
  ) async {
    final repository = _Repository(const EmergencySnapshot(coverageVerified: true));
    addTearDown(repository.close);
    await _show(tester, repository: repository, page: const EmergencyPage());
    expect(find.text(t.emergencyLifeRisk), findsOneWidget);
    expect(find.text(t.connectsNeighbors), findsOneWidget);
    expect(find.widgetWithText(FilledButton, t.callAction), findsNWidgets(3));
    expect(find.text(t.activateLocalEmergency), findsNothing);
    expect(find.text(t.emergencyBoardActivateMode), findsNothing);
  });

  testWidgets('tres toques guardan una sola vez y el toque repetido durante el envío no duplica', (
    tester,
  ) async {
    final repository = _Repository(const EmergencySnapshot(coverageVerified: true))
      ..pending = Completer<void>();
    addTearDown(repository.close);
    await _show(tester, repository: repository);
    var taps = 0;
    Future<void> tap(String label) async {
      taps++;
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await tap(t.emergencyNeedHelp); // 1: dashboard.
    await tap(t.emergencyNeedWater); // 2: need.
    await tester.enterText(find.byType(TextFormField).first, 'Necesidad ficticia de agua');
    await tap(t.emergencySendRequest); // 3: submit; typing does not add a tap.
    expect(taps, 3);
    expect(repository.drafts, hasLength(1));
    final draft = repository.drafts.single;
    expect(draft.id, isNotEmpty);
    expect(draft.idempotencyKey, isNotEmpty);
    expect(draft.id, isNot(draft.idempotencyKey));
    expect(draft.need, EmergencyNeed.water);
    expect(draft.description, 'Necesidad ficticia de agua');
    await tester.tap(
      find.text(t.emergencySendRequest),
    ); // Repeated submission, outside the three-tap flow.
    await tester.pump();
    expect(repository.drafts, hasLength(1));
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(OwnHelpRequestPage), findsOneWidget);
    expect(repository.snapshot.requests, hasLength(1));
    expect(repository.snapshot.requests.single.id, draft.id);
    expect(repository.snapshot.requests.single.idempotencyKey, draft.idempotencyKey);
    expect(find.text(t.emergencyRequestLocalHelp), findsOneWidget);
  });

  testWidgets('reintentar tras un fallo conserva id y clave del borrador', (tester) async {
    final repository = _Repository(const EmergencySnapshot(coverageVerified: true))
      ..failNext = true;
    addTearDown(repository.close);
    await _show(
      tester,
      repository: repository,
      page: const HelpRequestFormPage(need: EmergencyNeed.water),
    );
    await tester.tap(find.text(t.emergencySendRequest));
    await tester.pumpAndSettle();
    expect(find.text(t.emergencySaveFailed), findsOneWidget);
    await tester.tap(find.text(t.emergencySendRequest));
    await tester.pumpAndSettle();
    expect(repository.drafts, hasLength(2));
    expect(repository.drafts.last.id, repository.drafts.first.id);
    expect(repository.drafts.last.idempotencyKey, repository.drafts.first.idempotencyKey);
    expect(repository.snapshot.requests, hasLength(1));
  });

  for (final status in HelpRequestStatus.values) {
    testWidgets(
      'pedido ${status.name}: mensaje, alternativas y motivo sin identidad de quien ayuda',
      (tester) async {
        final request = _request(status);
        final repository = _Repository(
          EmergencySnapshot(coverageVerified: true, requests: [request]),
        );
        addTearDown(repository.close);
        await _show(
          tester,
          repository: repository,
          page: OwnHelpRequestPage(requestId: request.id),
        );
        final message = switch (status) {
          HelpRequestStatus.local => t.emergencyRequestLocalHelp,
          HelpRequestStatus.sent => t.emergencyRequestSentHelp,
          HelpRequestStatus.seen => t.emergencyRequestSeenHelp,
          HelpRequestStatus.onTheWay => t.emergencyRequestOnTheWayHelp,
          HelpRequestStatus.attended => t.emergencyRequestAttendedHelp,
          HelpRequestStatus.referred ||
          HelpRequestStatus.closedUnattended => t.emergencyRequestClosedHelp,
        };
        expect(find.text(message), findsOneWidget);
        _expectAlternatives(t);
        expect(find.text(t.emergencyConfirmAttendance), findsNothing);
        if (request.reason != null) {
          expect(find.text(t.emergencyReason(request.reason!)), findsOneWidget);
          expect(find.text(t.emergencyNextStep(request.nextStep!)), findsOneWidget);
        }
        if (status == HelpRequestStatus.sent) {
          expect(find.text(t.emergencyUnreviewedMinutes(10)), findsOneWidget);
        }
        if (status == HelpRequestStatus.onTheWay) {
          // An allowlist catches any extra identity/contact text, not just a known name.
          String hour(DateTime value) => DateFormat.Hm(t.localeName).format(value.toLocal());
          final publicText = tester
              .widgetList<Text>(
                find.descendant(
                  of: find.byType(EmergencyAlternatives),
                  matching: find.byType(Text),
                ),
              )
              .toSet();
          final privateText = tester
              .widgetList<Text>(find.byType(Text))
              .where((widget) => !publicText.contains(widget))
              .map((widget) => widget.data);
          expect(
            privateText,
            unorderedEquals([
              t.emergencyMyRequest,
              // The state band.
              t.emergencyRequestOnTheWay,
              message,
              // What was asked and where.
              t.emergencyNeedWater,
              request.description,
              request.locationLabel,
              // The timeline: creation and receipt keep their hour; only the next step is ahead.
              t.statusSavedOnPhone,
              hour(request.createdAt),
              t.statusSent,
              hour(request.sentAt!),
              t.emergencyRequestOnTheWay,
              hour(request.updatedAt),
              t.emergencyRequestAttended,
            ]),
          );
        }
      },
    );
  }

  testWidgets('confirmar atención exige la capacidad explícita del pedido', (tester) async {
    final request = _request(HelpRequestStatus.onTheWay, canConfirm: true);
    final repository = _Repository(EmergencySnapshot(coverageVerified: true, requests: [request]));
    addTearDown(repository.close);
    await _show(
      tester,
      repository: repository,
      page: OwnHelpRequestPage(requestId: request.id),
    );
    expect(find.widgetWithText(FilledButton, t.emergencyConfirmAttendance), findsOneWidget);
  });

  testWidgets('modo avión simulado: sin acuse queda local y avisa que no hay conexión', (
    tester,
  ) async {
    final request = _request(HelpRequestStatus.local);
    final repository = _Repository(EmergencySnapshot(coverageVerified: true, requests: [request]));
    addTearDown(repository.close);
    await _show(
      tester,
      repository: repository,
      page: OwnHelpRequestPage(requestId: request.id),
      connected: false,
    );
    expect(find.text(t.emergencyRequestLocalHelp), findsOneWidget);
    expect(find.text(t.emergencyOfflineWarning), findsOneWidget);
    expect(find.text(t.statusSent), findsNothing);
    _expectAlternatives(t);
  });

  testWidgets('práctica guarda local, deduplica y preparar SMS no abre un compositor externo', (
    tester,
  ) async {
    final sms = _SmsSpy();
    final container = await _show(tester, practice: true, sms: sms);
    final repository = container.read(emergencyRepositoryProvider);
    expect(repository, isA<PracticeEmergencyRepository>());
    // Even if personal contacts are available, practice must never use them.
    await container
        .read(emergencyContactsRepositoryProvider)!
        .save(
          const EmergencyContact(
            id: 'test-contact',
            name: 'Contacto ficticio',
            phone: '+999000000000',
          ),
        );
    await tester.tap(find.text(t.emergencyNeedHelp));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.emergencyNeedWater));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.emergencySavePractice));
    await tester.pumpAndSettle();
    final request = container.read(emergencySnapshotProvider).value!.requests.single;
    expect(request.status, HelpRequestStatus.local);
    final repeated = await repository.saveRequest(
      HelpRequestDraft(
        id: request.id,
        idempotencyKey: request.idempotencyKey,
        need: request.need,
        description: request.description,
        locationLabel: request.locationLabel,
        approximateLocation: request.approximateLocation,
      ),
    );
    expect(repeated.id, request.id);
    await tester.pump(const Duration(minutes: 2));
    expect(container.read(emergencySnapshotProvider).value!.requests, hasLength(1));
    expect(find.text(t.emergencyRequestLocalHelp), findsOneWidget);
    expect(find.text(t.statusSent), findsNothing);
    await tester.tap(find.text(t.emergencyPrepareSms));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining(t.emergencyPracticeExternal), findsOneWidget);
    expect(sms.calls, 0);
  });
}
