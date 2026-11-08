import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/features/emergencias/data/help_request_queue.dart';

void main() {
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
      queue.save(requestId: requestId, idempotencyKey: key, body: {'necesidad': 'agua'}),
      queue.save(requestId: requestId, idempotencyKey: key, body: {'necesidad': 'agua'}),
    ]);
    expect(saved[1].id, saved[0].id);
    expect(await states.moveNext(), isTrue);
    expect(states.current?.status, SubmissionStatus.savedOnPhone);
    expect((await local.database.getUploadQueueStats()).count, 1);
    final command = (await local.database.getNextCrudTransaction())!.crud.single;
    expect(command.id, saved[0].id);
    expect(jsonDecode(command.opData!['cuerpo'] as String), {'id': requestId, 'necesidad': 'agua'});

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
    await queue.save(requestId: newLocalId(), idempotencyKey: key, body: {});
    final second = newLocalId();
    await expectLater(
      queue.save(requestId: second, idempotencyKey: key, body: {}),
      throwsStateError,
    );
    expect(await queue.watch(second).first, isNull);
    expect((await local.database.getUploadQueueStats()).count, 1);
  });
}
