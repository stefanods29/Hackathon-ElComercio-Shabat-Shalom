import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/features/emergencias/data/powersync_emergency_board.dart';
import 'package:vecinal/features/emergencias/data/providers.dart';
import 'package:vecinal/features/emergencias/domain/public_emergency_board.dart';
import 'package:vecinal/features/emergencias/presentation/public_emergency_board_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class _DownloadedBoard implements EmergencyBoardRepository {
  const _DownloadedBoard(this.snapshot);
  final PublicEmergencySnapshot snapshot;
  @override
  Stream<PublicEmergencySnapshot> watch() => Stream.value(snapshot);
}

void main() {
  const zone = 'zona-de-prueba';
  final report = DateTime.utc(2026, 11, 8, 6);

  test('el tablero reabre cifrado sin conexión y filtra filas fuera de su zona', () async {
    final folder = await Directory.systemTemp.createTemp('vecinal-board-');
    addTearDown(() => folder.delete(recursive: true));
    final store = InMemorySecureStore();
    final databasePath = path.join(folder.path, 'account.db');
    Future<LocalSyncDatabase> open() =>
        LocalSyncDatabase.open(path: databasePath, store: store, accountId: 'cuenta');
    final initial = await open();
    addTearDown(initial.close);
    Future<void> seed(String table, String id, Map<String, Object?> data) => initial.database
        .execute('INSERT INTO ps_data__$table (id, data) VALUES (?, ?)', [id, jsonEncode(data)]);
    final group = {
      'zona_id': zone,
      'celda': 'celda-publica',
      'necesidad': 'agua',
      'cantidad': 3,
      'actualizado_en': report.toIso8601String(),
    };
    await seed('agregados_celda', 'grupo', group);
    await seed('agregados_celda', 'demasiado-pequeno', {...group, 'cantidad': 2});
    await seed('agregados_celda', 'grupo-ajeno', {...group, 'zona_id': 'otra'});
    final resource = {
      'zona_id': zone,
      'tipo': 'agua',
      'cantidad': 18,
      'celda': 'celda-publica',
      'reportado_en': report.toIso8601String(),
      'umbral_segundos': 7200,
      'verificacion': 'verificado',
      'confirmaciones': 3,
      'fuente_url': 'https://example.test/agua',
      'oficial': 1,
    };
    await seed('recursos_publicos', 'recurso', resource);
    await seed('recursos_publicos', 'otro', {...resource, 'zona_id': 'otra'});
    await initial.close();

    final reopened = await open();
    addTearDown(reopened.close);
    expect(reopened.database.currentStatus.connected, isFalse);
    final snapshot = await PowerSyncEmergencyBoard(reopened.database, zoneId: zone).watch().first;
    expect(snapshot.demands.single.count, 3);
    expect(snapshot.demands.single.cell, 'celda-publica');
    expect(snapshot.resources.single.id, 'recurso');
    expect(snapshot.resources.single.source.toString(), 'https://example.test/agua');
    expect(snapshot.resources.single.official, isTrue);
    expect(snapshot.resources.single.staleAfter, const Duration(hours: 2));
  });

  testWidgets('la copia offline marca cada recurso en su umbral y conserva la fuente', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var now = report.add(const Duration(seconds: 59));
    final snapshot = PublicEmergencySnapshot(
      demands: [CellDemand(cell: 'celda-publica', need: 'agua', count: 3, updatedAt: report)],
      resources: [
        PublicCriticalResource(
          id: 'agua',
          kind: 'agua',
          quantity: 18,
          cell: 'celda-publica',
          reportedAt: report,
          staleAfter: const Duration(minutes: 1),
          verification: 'verificado',
          confirmations: 3,
          official: true,
          label: 'Punto de agua',
          source: Uri.parse('https://example.test/agua'),
        ),
        PublicCriticalResource(
          id: 'albergue',
          kind: 'albergue',
          quantity: 30,
          cell: 'celda-publica',
          reportedAt: report,
          staleAfter: const Duration(minutes: 2),
          verification: 'sin_verificar',
          confirmations: 0,
          official: false,
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clockProvider.overrideWithValue(() => now),
          emergencyBoardRepositoryProvider.overrideWithValue(_DownloadedBoard(snapshot)),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const PublicEmergencyBoardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('3 pedidos · Agua'), findsOneWidget);
    expect(find.text('Fuente oficial · https://example.test/agua'), findsOneWidget);
    expect(find.text('Fecha de verificación no disponible.'), findsOneWidget);
    expect(find.textContaining('116, 105 o 106'), findsOneWidget);
    expect(find.text('Reportado hace un momento'), findsNWidgets(2));
    expect(find.textContaining('Posiblemente desactualizado'), findsNothing);

    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Reportado hace 1 minuto'), findsNWidgets(2));
    expect(find.textContaining('Posiblemente desactualizado'), findsOneWidget);

    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    expect(find.textContaining('Posiblemente desactualizado'), findsNWidgets(2));
    expect(find.text('Punto de agua'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
