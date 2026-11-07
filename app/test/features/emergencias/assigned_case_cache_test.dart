import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:powersync/powersync.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';

class OfflineConnector extends PowerSyncBackendConnector {
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async => null;

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {}
}

void main() {
  late InMemorySecureStore store;
  late Directory directory;
  late String casePath;
  late DateTime now;
  final expires = DateTime.utc(2026, 11, 7, 12);
  const key = 'powersync.database.cases.neighbor-demo';

  AssignedCaseCache cache() => AssignedCaseCache(
    path: casePath,
    store: store,
    accountId: 'neighbor-demo',
    connector: OfflineConnector(),
    clock: () => now,
  );

  setUp(() async {
    store = InMemorySecureStore();
    directory = await Directory.systemTemp.createTemp('vecinal-cases-test-');
    casePath = path.join(directory.path, 'case.db');
    now = expires.subtract(const Duration(minutes: 2));
    final cases = await LocalSyncDatabase.open(
      path: casePath,
      store: store,
      accountId: 'cases.neighbor-demo',
      schema: assignedCaseSchema,
    );
    await cases.database.execute(
      'INSERT INTO pedidos_ayuda (id, detalle, vence_en) VALUES (?, ?, ?)',
      ['caso-sintetico', 'Detalle sintético', expires.toIso8601String()],
    );
    await cases.close();
  });

  tearDown(() => directory.delete(recursive: true));

  test('vence sin conexión y borra solo el archivo y la clave del caso', () async {
    final wall = await LocalSyncDatabase.open(
      path: path.join(directory.path, 'wall.db'),
      store: store,
      accountId: 'neighbor-demo',
    );
    addTearDown(wall.close);
    await wall.database.execute("INSERT INTO comandos (id, tipo) VALUES ('test', 'publish')");
    final cases = cache();
    addTearDown(cases.close);
    await cases.restore();
    expect((await cases.watch().first)?.detail, 'Detalle sintético');
    expect(await store.read(key), isNotNull);

    final updates = StreamIterator(cases.watch());
    addTearDown(updates.cancel);
    expect(await updates.moveNext(), isTrue);
    now = expires;
    await cases.review();
    expect(await updates.moveNext(), isTrue);
    expect(updates.current, isNull);
    expect(await store.read(key), isNull);
    expect(await File(casePath).exists(), isFalse);
    expect((await wall.database.getUploadQueueStats()).count, 1);
    expect(await store.read('powersync.database.neighbor-demo'), isNotNull);
  });

  test('al reabrir sin conexión se purga el caso vencido antes de mostrarlo', () async {
    now = expires.add(const Duration(minutes: 1));
    final cases = cache();
    addTearDown(cases.close);
    await cases.restore();
    expect(await cases.watch().first, isNull);
    expect(await store.read(key), isNull);
    expect(await File(casePath).exists(), isFalse);
  });

  test('cerrar la sesión borra un caso todavía válido e impide reabrirlo', () async {
    final cases = cache();
    addTearDown(cases.close);
    await cases.wipeForSignOut();
    expect(await File(casePath).exists(), isFalse);
    expect(await store.read(key), isNull);
    await expectLater(cases.request('caso-sintetico'), throwsStateError);
  });
}
