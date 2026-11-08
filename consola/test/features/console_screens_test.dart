import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/network/problem_details.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/session/auth_api.dart';
import 'package:vecinal_consola/core/session/inactivity_guard.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/theme/console_theme.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/core/ui/problem_notice.dart';
import 'package:vecinal_consola/features/avisos_urgentes/data/urgent_notices_providers.dart';
import 'package:vecinal_consola/features/avisos_urgentes/presentation/urgent_notices_banner.dart';
import 'package:vecinal_consola/features/casos/data/cases_providers.dart';
import 'package:vecinal_consola/features/casos/domain/cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/casos/presentation/case_action_dialog.dart';
import 'package:vecinal_consola/features/casos/presentation/cases_queue_page.dart';
import 'package:vecinal_consola/features/celdas/data/cells_providers.dart';
import 'package:vecinal_consola/features/celdas/domain/cells.dart';
import 'package:vecinal_consola/features/celdas/presentation/cells_page.dart';
import 'package:vecinal_consola/features/ingreso/sign_in_page.dart';
import 'package:vecinal_consola/features/moderacion/data/moderation_repositories.dart';
import 'package:vecinal_consola/features/moderacion/presentation/moderation_page.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

final _now = DateTime.utc(2026, 11, 8, 12);
const _environment = ConsoleEnvironment(
  apiBaseUrl: 'https://example.invalid',
  inactivity: Duration(minutes: 2),
);
const _operator = Operator(
  id: 'test-operator',
  displayName: 'Cuenta ficticia',
  zoneId: 'test-zone',
  roles: {OperationalRole.coordinator},
);

EmergencyCase _case({int version = 1}) => EmergencyCase(
  id: 'test-case',
  version: version,
  priority: CasePriority.high,
  need: EmergencyNeed.water,
  status: CaseStatus.seen,
  cellLabel: 'Celda ficticia',
  createdAt: _now.subtract(const Duration(minutes: 10)),
  unreviewedSince: _now.subtract(const Duration(minutes: 10)),
);

/// Every HTTP call stays in memory. Unexpected routes fail instead of reaching a socket.
class _Api implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  late (int, Object?) Function(RequestOptions) reply;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = reply(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  Dio client() => createApiClient(_environment)..httpClientAdapter = this;
  ConsoleApi console() {
    final dio = client();
    addTearDown(() => dio.close(force: true));
    return ConsoleApi(dio, onUnauthorized: () {});
  }
}

Map<String, Object?> _session({bool operational = true}) => {
  'tokenDeAcceso': 'fictitious-access',
  'refreshToken': 'fictitious-refresh',
  'expiraEn': _now.add(const Duration(hours: 1)).toIso8601String(),
  'refreshExpiraEn': _now.add(const Duration(days: 1)).toIso8601String(),
  'usuario': {
    'id': _operator.id,
    'nombreVisible': _operator.displayName,
    'zonaId': _operator.zoneId,
    'roles': operational ? ['coordinador'] : ['vecino'],
  },
};

class _Cases implements CasesRepository {
  final attempts = <({String id, int version, CaseCommand command, String key})>[];
  bool conflict = false;
  @override
  Future<List<EmergencyCase>> queue(String zoneId) async => [_case()];
  @override
  Future<EmergencyCase> detail(String caseId) async => _case(version: 2);
  @override
  Future<List<AvailablePerson>> availablePeople(String zoneId) async => [];
  @override
  Future<EmergencyCase> apply(
    String caseId, {
    required int seenVersion,
    required CaseCommand command,
    required String idempotencyKey,
  }) async {
    attempts.add((id: caseId, version: seenVersion, command: command, key: idempotencyKey));
    if (conflict && attempts.length == 1) throw demoProblem(409, 'conflicto_de_version');
    return _case(version: seenVersion + 1);
  }
}

final _cells = [
  CellAggregate(
    id: 'test-cell',
    label: 'Celda ficticia',
    bounds: const CellBounds(south: 0, west: 0, north: 1, east: 1),
    total: CellCount(null),
    byNeed: {
      EmergencyNeed.water: CellCount(2),
      EmergencyNeed.food: CellCount(3),
      EmergencyNeed.medicine: CellCount(4),
    },
  ),
];

class _Cells implements CellsRepository {
  @override
  Future<CellsSnapshot> cells(String zoneId) async => CellsSnapshot(cells: _cells, updatedAt: _now);
}

ProviderContainer _container({
  AuthApi? auth,
  DateTime Function()? clock,
  _Cases? cases,
  _Api? api,
  bool operator = true,
  bool cells = false,
}) {
  final container = ProviderContainer(
    overrides: [
      consoleEnvironmentProvider.overrideWithValue(_environment),
      clockProvider.overrideWithValue(clock ?? () => _now),
      if (operator) currentOperatorProvider.overrideWithValue(_operator),
      if (auth != null) authApiProvider.overrideWithValue(auth),
      if (cases != null) casesRepositoryProvider.overrideWithValue(cases),
      if (cells) cellsRepositoryProvider.overrideWithValue(_Cells()),
      if (api != null) ...[
        moderationRepositoryProvider.overrideWithValue(HttpModerationRepository(api.console())),
        urgentNoticesRepositoryProvider.overrideWithValue(
          HttpUrgentNoticesRepository(api.console()),
        ),
      ],
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _show(
  WidgetTester tester,
  ProviderContainer container,
  Widget page, {
  double scale = 1,
  GoRouter? router,
  Size size = const Size(1000, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Widget builder(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: router == null
          ? MaterialApp(
              theme: ConsoleTheme.light(),
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: builder,
              home: Scaffold(body: page),
            )
          : MaterialApp.router(
              theme: ConsoleTheme.light(),
              locale: const Locale('es'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: builder,
              routerConfig: router,
            ),
    ),
  );
  await tester.pumpAndSettle();
  // Dispose timers, focus handlers and map widgets before the container is closed.
  addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
}

void main() {
  late AppLocalizations t;
  setUpAll(() async => t = await AppLocalizations.delegate.load(const Locale('es')));

  testWidgets('ingreso sin rol operativo verifica OTP, cierra la sesión remota y lo explica', (
    tester,
  ) async {
    final api = _Api()
      ..reply = (request) => switch (request.path) {
        '/v1/auth/otp' => (202, {'reintentarEnSegundos': 60, 'expiraEnSegundos': 300}),
        '/v1/auth/otp/verificar' => (200, _session(operational: false)),
        '/v1/auth/cerrar-sesion' => (204, null),
        _ => throw StateError('Unexpected route ${request.path}'),
      };
    final dio = api.client();
    addTearDown(() => dio.close(force: true));
    final container = _container(auth: AuthApi(dio), operator: false);
    await _show(tester, container, const SignInPage());
    await tester.enterText(find.byType(TextField), '+999000000000');
    await tester.tap(find.text(t.signInSendCode));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text(t.signInEnter));
    await tester.pumpAndSettle();
    expect(container.read(sessionProvider), isA<SignedOut>());
    expect(await container.read(sessionProvider.notifier).accessToken(), isNull);
    expect(find.text(t.signInNotOperational), findsOneWidget);
    expect(api.requests.map((request) => request.path), [
      '/v1/auth/otp',
      '/v1/auth/otp/verificar',
      '/v1/auth/cerrar-sesion',
    ]);
    expect(api.requests[1].data, {'telefono': '+999000000000', 'codigo': '123456'});
    expect(api.requests.last.headers['Authorization'], 'Bearer fictitious-access');
  });

  testWidgets('inactividad avisa al minuto y cierra sesión al vencer con reloj controlado', (
    tester,
  ) async {
    var now = _now;
    final api = _Api()
      ..reply = (request) => switch (request.path) {
        '/v1/auth/otp/verificar' => (200, _session()),
        '/v1/auth/cerrar-sesion' => (204, null),
        _ => throw StateError('Unexpected route ${request.path}'),
      };
    final dio = api.client();
    addTearDown(() => dio.close(force: true));
    final container = _container(auth: AuthApi(dio), operator: false, clock: () => now);
    await tester.runAsync(
      () => container.read(sessionProvider.notifier).verifyCode('+999000000000', '123456'),
    );
    await _show(tester, container, const InactivityGuard(child: SizedBox.expand()));
    now = _now.add(const Duration(seconds: 59));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(t.inactivityWarningTitle), findsNothing);
    now = _now.add(const Duration(seconds: 60));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(t.inactivityWarningTitle), findsOneWidget);
    expect(find.text(t.inactivityWarningCountdown(60)), findsOneWidget);
    expect(container.read(sessionProvider), isA<SignedIn>());
    now = _now.add(const Duration(seconds: 119));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(sessionProvider), isA<SignedIn>());
    now = _now.add(const Duration(seconds: 120));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect((container.read(sessionProvider) as SignedOut).reason, SignOutReason.inactivity);
    expect(api.requests.last.path, '/v1/auth/cerrar-sesion');
    expect(await container.read(sessionProvider.notifier).accessToken(), isNull);
  });

  testWidgets('teclado durante el aviso reinicia el plazo de inactividad', (tester) async {
    var now = _now;
    const demo = ConsoleEnvironment(
      apiBaseUrl: 'https://example.invalid',
      demoData: true,
      inactivity: Duration(minutes: 2),
    );
    final container = ProviderContainer(
      overrides: [
        consoleEnvironmentProvider.overrideWithValue(demo),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).enterDemo(OperationalRole.coordinator);
    await _show(tester, container, const InactivityGuard(child: SizedBox.expand()));
    now = _now.add(const Duration(seconds: 60));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text(t.inactivityWarningTitle), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.text(t.inactivityWarningTitle), findsNothing);
    now = _now.add(const Duration(seconds: 120));
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(sessionProvider), isA<SignedIn>());
    expect(find.text(t.inactivityWarningCountdown(60)), findsOneWidget);
  });

  testWidgets('cola al 200 % sin desbordes se recorre y abre con Tab y Enter con foco visible', (
    tester,
  ) async {
    final container = _container(cases: _Cases());
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: CasesQueuePage()),
        ),
        GoRoute(
          path: Routes.caseDetail('test-case'),
          builder: (_, _) => const Scaffold(body: Text('Detalle ficticio')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await _show(
      tester,
      container,
      const SizedBox(),
      scale: 2,
      router: router,
      size: const Size(800, 900),
    );
    expect(tester.takeException(), isNull);
    final cards = find.byType(FocusableCard);
    expect(cards, findsOneWidget);
    // No pointer taps: traverse from the refresh button to the case.
    var focused = false;
    for (var index = 0; index < 6; index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final card = tester.widget<Card>(find.descendant(of: cards, matching: find.byType(Card)));
      final shape = card.shape! as RoundedRectangleBorder;
      if (shape.side.width == 3) {
        expect(shape.side.color, Theme.of(tester.element(cards)).colorScheme.primary);
        focused = true;
        break;
      }
    }
    expect(focused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Detalle ficticio'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('409 conserva motivo y recarga versión y clave antes de reintentar', (tester) async {
    final cases = _Cases()..conflict = true;
    final container = _container(cases: cases);
    await _show(
      tester,
      container,
      Builder(
        builder: (context) => FilledButton(
          onPressed: () =>
              showCaseActionDialog(context, seen: _case(), action: CaseAction.closeUnattended),
          child: const Text('Abrir prueba'),
        ),
      ),
    );
    await tester.tap(find.text('Abrir prueba'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Motivo ficticio que debe conservarse');
    await tester.tap(find.text(t.actionConfirm));
    await tester.pumpAndSettle();
    expect(find.text(t.problemVersionConflictTitle), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Motivo ficticio que debe conservarse',
    );
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, t.actionConfirm)).onPressed,
      isNull,
    );
    await tester.tap(find.text(t.reloadKeepingText));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Motivo ficticio que debe conservarse',
    );
    await tester.tap(find.text(t.actionConfirm));
    await tester.pumpAndSettle();
    expect(cases.attempts, hasLength(2));
    expect(cases.attempts.map((attempt) => attempt.version), [1, 2]);
    expect(
      cases.attempts.map((attempt) => (attempt.command as CloseUnattended).reason),
      everyElement('Motivo ficticio que debe conservarse'),
    );
    expect(cases.attempts.last.key, isNot(cases.attempts.first.key));
    expect(find.byType(CaseActionDialog), findsNothing);
  });

  final errors = <String, (String Function(AppLocalizations), String Function(AppLocalizations))>{
    'conflicto_de_version': (
      (t) => t.problemVersionConflictTitle,
      (t) => t.problemVersionConflictAction,
    ),
    'transicion_invalida': (
      (t) => t.problemInvalidTransitionTitle,
      (t) => t.problemInvalidTransitionAction,
    ),
    'no_autenticado': ((t) => t.problemUnauthenticatedTitle, (t) => t.problemUnauthenticatedAction),
    for (final code in ['prohibido', 'rol_requerido', 'nivel_de_confianza_insuficiente'])
      code: ((t) => t.problemForbiddenTitle, (t) => t.problemForbiddenAction),
    'recurso_no_encontrado': ((t) => t.problemNotFoundTitle, (t) => t.problemNotFoundAction),
    for (final code in ['validacion', 'solicitud_invalida'])
      code: ((t) => t.problemValidationTitle, (t) => t.problemValidationAction),
    'directorio_invalido': (
      (t) => t.problemInvalidDirectoryTitle,
      (t) => t.problemInvalidDirectoryAction,
    ),
    'zona_sin_cobertura': ((t) => t.problemNoCoverageTitle, (t) => t.problemNoCoverageAction),
    'demasiadas_solicitudes': (
      (t) => t.problemTooManyTitle,
      (t) => t.problemTooManyActionSeconds(42),
    ),
    'servicio_no_disponible': ((t) => t.problemUnavailableTitle, (t) => t.problemUnavailableAction),
    'idempotency_key_reutilizada': (
      (t) => t.problemKeyReusedTitle,
      (t) => t.problemKeyReusedAction,
    ),
    'solicitud_en_curso': ((t) => t.problemInProgressTitle, (t) => t.problemInProgressAction),
  };
  for (final MapEntry(key: code, value: expected) in errors.entries) {
    testWidgets('ProblemNotice explica $code con texto del ARB', (tester) async {
      final error = ApiProblem(
        ProblemDetails(
          status: 409,
          title: 'Título de servidor ficticio',
          code: code,
          retryAfterSeconds: 42,
          detail: 'Detalle ficticio',
          fieldErrors: [const FieldError('campo', 'Motivo de prueba')],
        ),
      );
      await _show(tester, _container(), Center(child: ProblemNotice(error: error)));
      expect(find.text(expected.$1(t)), findsOneWidget);
      expect(find.text(expected.$2(t)), findsOneWidget);
      expect(find.text(t.problemCode(code)), findsOneWidget);
      expect(find.text('Detalle ficticio'), findsOneWidget);
      expect(find.text(t.problemField('campo', 'Motivo de prueba')), findsOneWidget);
    });
  }

  testWidgets('tabla de celdas oculta totales y muestra menos de 3 sin dibujar mapa nativo', (
    tester,
  ) async {
    // Desktop's unregistered map displays a placeholder; this test checks only the real table.
    await _show(tester, _container(cells: true), const CellsPage(), size: const Size(1200, 1600));
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.columns, hasLength(1 + EmergencyNeed.values.length));
    expect(find.text(t.cellsColumnTotal), findsNothing);
    expect(
      find.descendant(of: find.byType(DataTable), matching: find.text(t.cellsFewerThanThree)),
      findsNWidgets(4),
    );
    expect(find.descendant(of: find.byType(DataTable), matching: find.text('3')), findsOneWidget);
    expect(find.descendant(of: find.byType(DataTable), matching: find.text('2')), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  test('cellsGeoJson solo polígonos y nivel máximo publicado, sin sumar ni revelar conteos', () {
    final geo = cellsGeoJson(_cells, null);
    expect(geo, {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'id': 'test-cell',
          'properties': {'nivel': 'low'},
          'geometry': {
            'type': 'Polygon',
            'coordinates': [
              [
                [0.0, 0.0],
                [1.0, 0.0],
                [1.0, 1.0],
                [0.0, 1.0],
                [0.0, 0.0],
              ],
            ],
          },
        },
      ],
    });
    expect(_cells.single.countFor(null).value, 4); // Maximum, never 3 + 4.
    expect(cellsGeoJson(_cells, EmergencyNeed.water)['features'], [
      {
        'type': 'Feature',
        'id': 'test-cell',
        'properties': {'nivel': 'belowThreshold'},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [_cells.single.bounds.ring],
        },
      },
    ]);
  });

  testWidgets('moderación envía decisión y motivo con Idempotency-Key y retira el pendiente', (
    tester,
  ) async {
    Map<String, Object?> row(String state) => {
      'id': 'test-moderation',
      'tipoContenido': 'resena',
      'contenidoId': 'test-content',
      'estado': state,
      'motivo': 'spam',
      'ultimaAccion': state == 'resuelto' ? 'ocultar' : null,
      'creadoEn': _now.toIso8601String(),
      'actualizadoEn': _now.toIso8601String(),
    };
    final api = _Api()
      ..reply = (request) => switch ((request.method, request.path)) {
        ('GET', '/v1/moderacion/casos') => (
          200,
          {
            'datos': [row('pendiente')],
          },
        ),
        ('POST', '/v1/moderacion/casos/test-moderation/decision') => (200, row('resuelto')),
        _ => throw StateError('Unexpected route ${request.path}'),
      };
    await _show(tester, _container(api: api), const ModerationPage());
    await tester.tap(find.text(t.moderationDecide));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.moderationHide));
    await tester.enterText(find.byType(TextField), 'Motivo ficticio de moderación');
    await tester.tap(find.text(t.moderationSend));
    await tester.pumpAndSettle();
    final request = api.requests.singleWhere((request) => request.method == 'POST');
    expect(request.path, '/v1/moderacion/casos/test-moderation/decision');
    expect(request.headers[idempotencyKeyHeader], isNotEmpty);
    expect(request.data, {'accion': 'ocultar', 'motivo': 'Motivo ficticio de moderación'});
    expect(find.text(t.moderationEmptyPending), findsOneWidget);
  });

  testWidgets('banner muestra pendientes y confirmar llama la ruta y vuelve a consultar', (
    tester,
  ) async {
    var confirmed = false;
    final api = _Api()
      ..reply = (request) => switch ((request.method, request.path)) {
        ('GET', '/v1/avisos-urgentes') => (
          200,
          {
            'datos': confirmed
                ? []
                : [
                    {
                      'id': 'test-notice',
                      'plantilla': 'pedido_por_escalar',
                      'casoId': 'test-case',
                      'creadoEn': _now.toIso8601String(),
                    },
                  ],
          },
        ),
        ('POST', '/v1/avisos-urgentes/test-notice/confirmar') => (() {
          confirmed = true;
          return (200, <String, Object?>{});
        })(),
        _ => throw StateError('Unexpected route ${request.path}'),
      };
    await _show(tester, _container(api: api), const UrgentNoticesBanner());
    expect(find.text(t.urgentBannerTitle(1)), findsOneWidget);
    expect(find.textContaining(t.urgentAboutToEscalate), findsOneWidget);
    await tester.tap(find.text(t.urgentConfirm));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
    final request = api.requests.singleWhere((request) => request.method == 'POST');
    expect(request.path, '/v1/avisos-urgentes/test-notice/confirmar');
    expect(request.headers[idempotencyKeyHeader], isNotEmpty);
    expect(api.requests.where((request) => request.method == 'GET'), hasLength(2));
    expect(find.text(t.urgentBannerTitle(1)), findsNothing);
  });
}
