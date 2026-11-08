import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/onboarding/tutorial_screen.dart';
import 'package:vecinal/l10n/app_localizations.dart';

Widget _withTexts(Widget child, {double textScale = 1}) {
  return MaterialApp(
    locale: const Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  testWidgets('la app abre en el muro de la zona', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: VecinalApp()));
    await tester.pumpAndSettle();

    expect(find.text('Muro de favores'), findsOneWidget);
    expect(find.text('Publicar'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Presto taladro por la tarde'), 200);
    expect(find.text('Presto taladro por la tarde'), findsOneWidget);
  });

  testWidgets('el tutorial conserva el paso al volver de Servicios', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: VecinalApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(VecinalApp)));
    unawaited(container.read(routerProvider).push<void>(Routes.tutorial));
    await tester.pumpAndSettle();

    final start = find.text('Comenzar tutorial');
    await tester.scrollUntilVisible(start, 120);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('Paso 1 de 6'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Paso 2 de 6'), findsOneWidget);
    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Abrir esta pantalla'));
    await tester.pumpAndSettle();
    expect(find.byType(DirectoryPage), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialScreen), findsOneWidget);
    expect(find.text('Paso 1 de 6'), findsOneWidget);
  });

  testWidgets('sin conexión avisa que los datos pueden haber cambiado', (tester) async {
    final sync = FakeSyncService(
      SyncStatus(
        connected: false,
        lastSyncedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
    );
    addTearDown(sync.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [syncServiceProvider.overrideWithValue(sync)],
        child: const VecinalApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin conexión'), findsOneWidget);
    expect(
      find.text('Estás viendo datos de hace 5 minutos; algunos pueden haber cambiado.'),
      findsOneWidget,
    );
  });

  testWidgets('cada estado de envío tiene texto, no solo color', (tester) async {
    for (final (status, text) in [
      (SubmissionStatus.savedOnPhone, 'Guardado en tu celular'),
      (SubmissionStatus.sent, 'Enviado'),
      (SubmissionStatus.couldNotComplete, 'No se pudo completar'),
    ]) {
      await tester.pumpWidget(_withTexts(SubmissionStatusChip(status: status)));
      expect(find.text(text), findsOneWidget);
    }
  });

  testWidgets('el estado se lee bien con letra grande (200 %)', (tester) async {
    await tester.pumpWidget(
      _withTexts(const SubmissionStatusChip(status: SubmissionStatus.savedOnPhone), textScale: 2),
    );
    expect(find.text('Guardado en tu celular'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
