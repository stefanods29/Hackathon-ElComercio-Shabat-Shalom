import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/security/operational_lock.dart';
import 'package:vecinal/core/security/sensitive_screen_protection.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';
import 'package:vecinal/features/emergencias/assigned_case_provider.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';
import 'package:vecinal/features/emergencias/presentation/operational_case_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class _CaseCache extends Mock implements AssignedCaseCache {}

class _DeviceLock implements OperationalLock {
  bool accepted = false;
  int attempts = 0;

  @override
  Future<bool> authenticate(OperationalPrompt prompt) async {
    attempts++;
    return accepted;
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  const caseId = '01970000-0000-7000-8000-000000000001';
  const user = LocalUser(neighborId: 'neighbor', displayName: 'Prueba', zoneId: 'zone');
  const channel = MethodChannel('test/pantalla_sensible');
  const secret = 'Detalle ficticio de la ubicación';
  const unlock = 'Desbloquear';
  late DateTime now;
  late _CaseCache cache;
  late _DeviceLock lock;
  late SensitiveScreenProtection protection;
  late List<MethodCall> calls;
  late AssignedCase? cached;

  setUp(() {
    now = DateTime.utc(2026, 11, 8);
    cache = _CaseCache();
    lock = _DeviceLock();
    calls = [];
    cached = AssignedCase(
      id: caseId,
      need: 'agua',
      priority: 'alta',
      stage: HelpRequestStage.onTheWay,
      version: 2,
      cell: 'celda-ficticia',
      expiresAt: now.add(const Duration(hours: 1)),
      location: (latitude: -12.01234, longitude: -77.01234, description: secret),
    );
    when(() => cache.accountId).thenReturn(user.neighborId);
    when(() => cache.watch()).thenAnswer((_) => Stream.value(cached));
    when(() => cache.review()).thenAnswer((_) async {});
    when(() => cache.request(caseId)).thenAnswer((_) async {});
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> show(WidgetTester tester, {Future<void> Function(MethodCall)? native}) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    protection = SensitiveScreenProtection(channel: channel);
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      await native?.call(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(const SignedIn(user))),
          assignedCaseCacheProvider.overrideWithValue(cache),
          operationalLockProvider.overrideWithValue(lock),
          sensitiveScreenProtectionProvider.overrideWithValue(protection),
          clockProvider.overrideWithValue(() => now),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const OperationalCasePage(caseId: caseId),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('solo abre el caso cuando la pantalla y la autenticación están listas', (
    tester,
  ) async {
    final nativeReady = Completer<void>();
    await show(
      tester,
      native: (call) async {
        if (call.method == 'setEnabled' && call.arguments == true) await nativeReady.future;
      },
    );
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, unlock)).onPressed,
      isNull,
    );
    expect(find.text(secret), findsNothing);
    verifyNever(() => cache.request(caseId));
    nativeReady.complete();
    await tester.pumpAndSettle();

    await tester.tap(find.text(unlock));
    await tester.pumpAndSettle();
    expect(find.text('No se confirmó tu identidad.'), findsOneWidget);
    expect(find.text(secret), findsNothing);
    verifyNever(() => cache.watch());

    lock.accepted = true;
    await tester.tap(find.text(unlock));
    await tester.pumpAndSettle();
    expect(find.text(secret), findsOneWidget);
    verify(() => cache.review()).called(1);
    expect(calls.where((call) => call.method == 'setEnabled').map((call) => call.arguments), [
      true,
    ]);

    final navigator = Navigator.of(tester.element(find.byType(OperationalCasePage)));
    unawaited(navigator.push<void>(MaterialPageRoute(builder: (_) => const Scaffold())));
    await tester.pumpAndSettle();
    expect(find.text(secret, skipOffstage: false), findsNothing);
    expect(calls.where((call) => call.method == 'setEnabled').map((call) => call.arguments), [
      true,
      false,
    ]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la actividad reinicia el límite y el caso vigente vuelve a abrirse sin red', (
    tester,
  ) async {
    lock.accepted = true;
    await show(tester);
    await tester.tap(find.text(unlock));
    await tester.pumpAndSettle();
    expect(find.text(secret), findsOneWidget);

    const fourMinutes = Duration(minutes: 4);
    now = now.add(fourMinutes);
    await tester.pump(fourMinutes);
    await tester.tap(find.text(secret));
    now = now.add(fourMinutes);
    await tester.pump(fourMinutes);
    expect(find.text(secret), findsOneWidget);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(find.text(secret), findsNothing);
    expect(find.text(unlock), findsOneWidget);

    await tester.tap(find.text(unlock));
    await tester.pumpAndSettle();
    expect(find.text(secret), findsOneWidget);
    expect(lock.attempts, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('al volver oculta el caso hasta terminar la revisión de la caché', (tester) async {
    lock.accepted = true;
    await show(tester);
    await tester.tap(find.text(unlock));
    await tester.pumpAndSettle();
    expect(find.text(secret), findsOneWidget);
    calls.clear();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text(secret), findsNothing);
    final checked = Completer<void>();
    when(() => cache.review()).thenAnswer((_) => checked.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text(secret), findsNothing);
    expect(calls.map((call) => call.method), contains('foregroundReady'));

    cached = null;
    checked.complete();
    await tester.pumpAndSettle();
    expect(find.text(secret), findsNothing);
    expect(find.text('El caso no está disponible en este celular.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('si falla el canal nativo, el detalle nunca llega a construirse', (tester) async {
    lock.accepted = true;
    await show(tester, native: (_) async => throw PlatformException(code: 'fallo-ficticio'));
    expect(find.text('No se pudo proteger esta pantalla.'), findsOneWidget);
    expect(find.text(secret), findsNothing);
    expect(find.text(unlock), findsNothing);
    expect(lock.attempts, 0);
    verifyNever(() => cache.request(caseId));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
