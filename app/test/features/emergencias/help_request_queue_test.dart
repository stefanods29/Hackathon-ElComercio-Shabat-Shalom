import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/storage/account_data_purge.dart';
import 'package:vecinal/core/storage/pending_photo_purger.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/authenticated_sync_session.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/emergencias/data/help_request_queue.dart';

import 'help_request_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('guarda el borrador una sola vez y lo recupera de la base cifrada', () async {
    final directory = await Directory.systemTemp.createTemp('help-request-queue-');
    addTearDown(() => directory.delete(recursive: true));
    final databasePath = path.join(directory.path, 'account.db');
    final store = InMemorySecureStore();
    Future<LocalSyncDatabase> open() =>
        LocalSyncDatabase.open(path: databasePath, store: store, accountId: 'account');

    final local = await open();
    addTearDown(local.close);
    final queue = HelpRequestQueue(local);
    final requestId = newLocalId();
    final key = newLocalId();
    final states = StreamIterator(queue.watch(requestId));
    addTearDown(states.cancel);
    expect(await states.moveNext(), isTrue);
    expect(states.current, isNull);

    final saved = await Future.wait([
      queue.save(requestId: requestId, idempotencyKey: key, body: helpRequestPayload),
      queue.save(requestId: requestId, idempotencyKey: key, body: helpRequestPayload),
    ]);
    expect(saved[1].id, saved[0].id);
    expect(await states.moveNext(), isTrue);
    expect(states.current?.status, SubmissionStatus.savedOnPhone);
    expect((await local.database.getUploadQueueStats()).count, 1);
    final command = (await local.database.getNextCrudTransaction())!.crud.single;
    expect(command.id, saved[0].id);
    expect(jsonDecode(command.opData!['cuerpo'] as String), {
      'id': requestId,
      'eventoId': '0192f461-18fd-7b77-8975-7debbaf14227',
      'necesidad': 'agua',
      'prioridad': 'media',
      'descripcion': 'Pedido ficticio',
      'ubicacion': {'lat': -12.01234, 'lng': -77.01234},
      'riesgoVital': false,
    });

    await states.cancel();
    await local.close();
    final bytes = await File(databasePath).openRead(0, 16).expand((chunk) => chunk).toList();
    expect(bytes, isNot('SQLite format 3\u0000'.codeUnits));
    final reopened = await open();
    addTearDown(reopened.close);
    final restored = await HelpRequestQueue(reopened).watch(requestId).first;
    expect(restored?.resourceId, requestId);
    expect(restored?.idempotencyKey, key);
    expect(restored?.status, SubmissionStatus.savedOnPhone);
    expect((await reopened.database.getUploadQueueStats()).count, 1);
  });

  test('una clave de envío no puede identificar dos pedidos', () async {
    final directory = await Directory.systemTemp.createTemp('help-request-key-');
    addTearDown(() => directory.delete(recursive: true));
    final local = await LocalSyncDatabase.open(
      path: path.join(directory.path, 'account.db'),
      store: InMemorySecureStore(),
      accountId: 'account',
    );
    addTearDown(local.close);
    final queue = HelpRequestQueue(local);
    final key = newLocalId();
    await queue.save(requestId: newLocalId(), idempotencyKey: key, body: helpRequestPayload);
    final second = newLocalId();
    await expectLater(
      queue.save(requestId: second, idempotencyKey: key, body: helpRequestPayload),
      throwsStateError,
    );
    expect(await queue.watch(second).first, isNull);
    expect((await local.database.getUploadQueueStats()).count, 1);
  });
  test('cerrar sesión elimina el pedido pendiente, el historial mínimo y la clave', () async {
    final directory = await Directory.systemTemp.createTemp('help-request-sign-out-');
    addTearDown(() => directory.delete(recursive: true));
    final accountId = newLocalId();
    final store = InMemorySecureStore();
    final session = await AuthenticatedSyncSession.open(
      user: LocalUser(neighborId: accountId, displayName: 'Prueba', zoneId: newLocalId()),
      directory: directory.path,
      store: store,
      environment: const AppEnvironment(apiBaseUrl: 'https://api.example.test', powersyncUrl: ''),
      getToken: () async => null,
      onSessionRevoked: () {},
    );
    addTearDown(() => session.close(purge: true));
    final queue = session.helpRequests.queue;
    await queue.save(
      requestId: newLocalId(),
      idempotencyKey: newLocalId(),
      body: helpRequestPayload,
    );
    await session.local.database.execute(
      "INSERT INTO pedidos_propios_cerrados (id, estado, version) VALUES (?, 'derivado', 3)",
      [newLocalId()],
    );
    expect((await session.local.database.getUploadQueueStats()).count, 1);
    final databasePath = path.join(directory.path, 'wall-$accountId.db');
    final keyName = 'powersync.database.$accountId';
    expect(await store.read(keyName), isNotNull);

    await purgeAccountData(
      accountId,
      pendingPhotos: const NoPendingPhotos(),
      closeSession: () => session.close(purge: true),
      discardStorage: (id) =>
          AuthenticatedSyncSession.discard(directory: directory.path, store: store, accountId: id),
    );
    expect(await store.read(keyName), isNull);
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      expect(await File('$databasePath$suffix').exists(), isFalse);
    }
    final reopened = await LocalSyncDatabase.open(
      path: databasePath,
      store: store,
      accountId: accountId,
    );
    addTearDown(reopened.close);
    expect(await reopened.database.getAll('SELECT id FROM envios'), isEmpty);
    expect(await reopened.database.getAll('SELECT id FROM pedidos_propios_cerrados'), isEmpty);
    expect(await reopened.database.getNextCrudTransaction(), isNull);
  });
}
