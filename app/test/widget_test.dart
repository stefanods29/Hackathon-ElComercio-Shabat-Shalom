import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
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
    expect(find.text('Presto taladro por la tarde'), findsOneWidget);
    expect(find.text('Publicar'), findsOneWidget);
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
