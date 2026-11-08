import 'dart:convert';
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

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vecinal-zona-');
    databasePath = path.join(directory.path, 'wall.db');
    store = InMemorySecureStore();
  });

  tearDown(() => directory.delete(recursive: true));

  Future<LocalSyncDatabase> open() =>
      LocalSyncDatabase.open(path: databasePath, store: store, accountId: account);

  test('al cambiar de zona no quedan filas de la zona anterior en el celular', () async {
    final local = await open();
    final db = local.database;
    Future<void> download(String table, String id, Map<String, Object?> data) =>
        db.execute('INSERT INTO ps_data__$table (id, data) VALUES (?, ?)', [id, jsonEncode(data)]);
    await download('servicios', 's-piloto', {'zona_id': 'zona-piloto', 'titulo': 'Gasfitería'});
    await download('resenas', 'r-ajena', {'servicio_id': 's-piloto', 'calificacion': 5});
    await download('publicaciones', 'p-ajena', {'zona_id': 'zona-piloto', 'titulo': 'Presto'});
    expect(await db.getAll('SELECT id FROM servicios'), hasLength(1));

    // What `AuthenticatedApp._activate` does with the session of the previous zone.
    final api = Dio();
    addTearDown(api.close);
    await PowerSyncSyncService(local, VecinalConnector(api)).disconnectAndWipeLocalData();

    final reopened = await open();
    addTearDown(reopened.close);
    for (final table in ['servicios', 'proveedores', 'resenas', 'fotos_resena', 'publicaciones']) {
      expect(await reopened.database.getAll('SELECT id FROM $table'), isEmpty, reason: table);
    }
  });
}
