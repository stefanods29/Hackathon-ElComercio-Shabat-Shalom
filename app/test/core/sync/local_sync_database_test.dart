import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/powersync_sync_service.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';

void main() {
  late Directory directory;
  late String databasePath;
  late InMemorySecureStore store;
  const account = 'neighbor';
  const keyName = 'powersync.database.$account';

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vecinal-powersync-');
    databasePath = path.join(directory.path, 'test.db');
    store = InMemorySecureStore();
  });

  tearDown(() => directory.delete(recursive: true));

  Future<LocalSyncDatabase> open() =>
      LocalSyncDatabase.open(path: databasePath, store: store, accountId: account);

  test('abre el esquema y solo los comandos entran a la cola de PowerSync', () async {
    final local = await open();
    addTearDown(local.close);
    final db = local.database;
    expect(await db.getAll('SELECT * FROM zonas'), isEmpty);
    expect(await db.getAll('SELECT * FROM publicaciones'), isEmpty);

    await db.writeTransaction((tx) async {
      await tx.execute("INSERT INTO envios (id, estado) VALUES ('a', 'savedOnPhone')");
      await tx.execute("INSERT INTO comandos (id, tipo) VALUES ('a', 'publish')");
    });

    final transaction = await db.getNextCrudTransaction();
    expect(transaction!.crud.single.table, 'comandos');
    expect((await db.getUploadQueueStats()).count, 1);
    expect((await db.getAll('SELECT * FROM envios')).single['id'], 'a');
  });

  test('conserva la base cifrada al reabrir y la elimina junto con la clave', () async {
    var local = await open();
    await local.database.execute("INSERT INTO envios (id, estado) VALUES ('a', 'savedOnPhone')");
    final key = await store.read(keyName);
    expect(key, isNotNull);
    await local.close();
    expect(
      await File(databasePath).readAsBytes().then((bytes) => bytes.take(16).toList()),
      isNot('SQLite format 3\u0000'.codeUnits),
    );

    await store.write(keyName, 'wrong-key');
    await expectLater(open(), throwsA(anything));
    await store.write(keyName, key!);

    local = await open();
    addTearDown(local.close);
    expect((await local.database.getAll('SELECT id FROM envios')).single['id'], 'a');
    await local.wipe();

    expect(await store.read(keyName), isNull);
    expect(await File(databasePath).exists(), isFalse);
    final fresh = await open();
    addTearDown(fresh.close);
    expect(await fresh.database.getAll('SELECT * FROM envios'), isEmpty);
    expect(await store.read(keyName), isNot(key));
  });

  test('una sesión revocada purga la cola y la clave local', () async {
    final local = await open();
    addTearDown(local.close);
    await local.database.execute("INSERT INTO comandos (id, tipo) VALUES ('a', 'publish')");
    final api = Dio();
    addTearDown(api.close);
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response(requestOptions: options, statusCode: 401, data: {'codigo': 'sesion_revocada'}),
          );
        },
      ),
    );
    Future<void>? wipe;
    late final PowerSyncSyncService sync;
    final connector = VecinalConnector(
      api,
      onSessionRevoked: () {
        wipe = Future<void>(sync.disconnectAndWipeLocalData);
      },
    );
    sync = PowerSyncSyncService(local, connector);

    await expectLater(connector.fetchCredentials(), throwsA(isA<SyncCredentialsFailure>()));
    await wipe!;
    expect(await File(databasePath).exists(), isFalse);
    expect(await store.read(keyName), isNull);
    expect((await sync.watch().first).pendingUploads, 0);
  });
}
