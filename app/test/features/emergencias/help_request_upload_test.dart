import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/features/emergencias/data/help_request_queue.dart';
import 'package:vecinal/features/emergencias/data/own_help_request_repository.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';
import 'package:vecinal/features/solidaridad/data/powersync_post_repository.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';

import 'help_request_fixture.dart';

void main() {
  const helpPath = '/v1/pedidos-ayuda';
  late Directory directory;
  late LocalSyncDatabase local;
  late InMemorySecureStore store;
  late Dio api;
  late DateTime now;
  late VecinalConnector connector;

  Future<LocalSyncDatabase> open() => LocalSyncDatabase.open(
    path: path.join(directory.path, 'account.db'),
    store: store,
    accountId: 'account',
  );

  Future<void> reopen() async {
    await local.close();
    local = await open();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('help-request-upload-');
    store = InMemorySecureStore();
    local = await open();
    now = DateTime.utc(2026, 11, 8);
    api = Dio(BaseOptions(baseUrl: 'https://api.example.test', validateStatus: (_) => true));
    connector = VecinalConnector(api, clock: () => now);
  });

  tearDown(() async {
    api.close(force: true);
    await local.close();
    await directory.delete(recursive: true);
  });

  void respond(
    RequestOptions request,
    RequestInterceptorHandler handler,
    int status,
    Object? body,
  ) => handler.resolve(Response(requestOptions: request, statusCode: status, data: body));

  void drop(RequestOptions request, RequestInterceptorHandler handler) =>
      handler.reject(DioException(requestOptions: request, type: DioExceptionType.connectionError));

  test('500 pedidos sobreviven a cortes y reaperturas sin pérdidas ni duplicados', () async {
    final queue = HelpRequestQueue(local, clock: () => now);
    final drafts = List.generate(500, (_) => (id: newLocalId(), key: newLocalId()));
    final beforeReceipt = <String>{};
    final afterReceipt = <String>{};
    final accepted = <String, String>{};
    final attempts = <String, int>{};
    for (final (index, draft) in drafts.indexed) {
      await queue.save(requestId: draft.id, idempotencyKey: draft.key, body: helpRequestPayload);
      if (index % 17 == 0) {
        beforeReceipt.add(draft.key);
      } else if (index % 11 == 0) {
        afterReceipt.add(draft.key);
      }
    }
    final interrupted = {...beforeReceipt, ...afterReceipt};
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          final key = request.headers[idempotencyKeyHeader] as String;
          final body = jsonDecode(request.data as String) as Map<String, Object?>;
          final id = body['id'] as String;
          attempts.update(key, (count) => count + 1, ifAbsent: () => 1);
          if (beforeReceipt.remove(key)) return drop(request, handler);
          final storedId = accepted.putIfAbsent(key, () => id);
          if (afterReceipt.remove(key)) return drop(request, handler);
          respond(request, handler, 200, {'id': storedId});
        },
      ),
    );

    expect((await local.database.getUploadQueueStats()).count, 500);
    await reopen();
    for (final (index, draft) in drafts.indexed) {
      if (interrupted.contains(draft.key)) {
        await expectLater(connector.uploadData(local.database), throwsStateError);
        final pending = await HelpRequestQueue(local).watch(draft.id).first;
        expect(pending?.status, SubmissionStatus.savedOnPhone);
        if (index == 0 || index == 11) await reopen();
        now = now.add(const Duration(minutes: 1));
      }
      await connector.uploadData(local.database);
    }

    expect(accepted, {for (final draft in drafts) draft.key: draft.id});
    expect(attempts, {
      for (final draft in drafts) draft.key: interrupted.contains(draft.key) ? 2 : 1,
    });
    expect(await local.database.getNextCrudTransaction(), isNull);
    expect(
      await local.database.getAll("SELECT id FROM envios WHERE estado = 'sent'"),
      hasLength(500),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test(
    'un rechazo se conserva en Emergencias y el siguiente comando de Solidaridad sale',
    () async {
      final queue = HelpRequestQueue(local);
      final posts = PowerSyncPostRepository(local.database, neighborId: 'account', zoneId: 'zone');
      final help = await queue.save(
        requestId: newLocalId(),
        idempotencyKey: newLocalId(),
        body: helpRequestPayload,
      );
      final post = await posts.publish(
        const NewPost(type: PostType.lend, category: 'herramientas', title: 'Favor de prueba'),
      );
      final requests = <(String, Object?, Object?)>[];
      api.interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            requests.add((request.path, request.headers[idempotencyKeyHeader], request.data));
            if (request.path == helpPath) {
              respond(request, handler, 409, {
                'codigo': 'zona_sin_cobertura',
                'title': 'Zona sin cobertura',
              });
            } else {
              respond(request, handler, 201, {});
            }
          },
        ),
      );

      await connector.uploadData(local.database);
      final rejected = await queue.watch(help.resourceId).first;
      expect(rejected?.status, SubmissionStatus.couldNotComplete);
      expect(rejected?.rejectionReason?.code, 'zona_sin_cobertura');
      expect(await posts.watchActionsToReview().first, isEmpty);
      expect((await posts.watchWall().first).single.id, post.resourceId);
      await connector.uploadData(local.database);
      expect(await local.database.getNextCrudTransaction(), isNull);
      expect(requests.map((request) => (request.$1, request.$2)), [
        (helpPath, help.idempotencyKey),
        ('/v1/publicaciones', post.idempotencyKey),
      ]);
      expect((jsonDecode(requests.last.$3 as String) as Map)['id'], post.resourceId);
      expect(
        (await local.database.get('SELECT estado FROM envios WHERE id = ?', [post.id]))['estado'],
        'sent',
      );
    },
  );

  test('el envío queda pendiente hasta que el acuse confirma el mismo pedido', () async {
    final queue = HelpRequestQueue(local);
    final draft = await queue.save(
      requestId: newLocalId(),
      idempotencyKey: newLocalId(),
      body: helpRequestPayload,
    );
    var attempts = 0;
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          final id = ++attempts == 1 ? newLocalId() : draft.resourceId;
          respond(request, handler, attempts == 1 ? 200 : 201, {'id': id});
        },
      ),
    );

    await expectLater(connector.uploadData(local.database), throwsStateError);
    final pending = OwnHelpRequestState(
      requestId: draft.resourceId,
      submission: await queue.watch(draft.resourceId).first,
    );
    expect(pending.savedOnPhone, isTrue);
    expect(pending.received, isFalse);
    expect(pending.sentAt, isNull);
    now = now.add(const Duration(minutes: 1));
    await connector.uploadData(local.database);
    final sent = OwnHelpRequestState(
      requestId: draft.resourceId,
      submission: await queue.watch(draft.resourceId).first,
    );
    expect(sent.savedOnPhone, isFalse);
    expect(sent.received, isTrue);
    expect(sent.sentAt, now);
    expect(attempts, 2);
  });
  test('422 es definitivo y descarta el texto libre del servidor', () async {
    final queue = HelpRequestQueue(local);
    final draft = await queue.save(
      requestId: newLocalId(),
      idempotencyKey: newLocalId(),
      body: helpRequestPayload,
    );
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          expect(request.method, 'POST');
          expect(request.path, helpPath);
          expect(request.headers[idempotencyKeyHeader], draft.idempotencyKey);
          respond(request, handler, 422, {
            'codigo': 'validacion',
            'title': helpRequestPayload.description,
            'detail': '-12.01234',
          });
        },
      ),
    );
    await connector.uploadData(local.database);
    final rejected = await queue.watch(draft.resourceId).first;
    expect(rejected?.status, SubmissionStatus.couldNotComplete);
    expect(rejected?.rejectionReason?.code, 'validacion');
    expect(rejected?.rejectionReason?.title, 'No se pudo completar');
    expect(rejected?.rejectionReason?.detail, isNull);
    expect(await local.database.getNextCrudTransaction(), isNull);
  });

  test('el cierre sincronizado retira la suscripción y cancela el reintento', () async {
    final opened = Completer<String>();
    final unsubscribed = Completer<void>();
    final repository = OwnHelpRequestRepository(
      local,
      subscribe: (id) async {
        opened.complete(id);
        return unsubscribed.complete;
      },
    );
    repository.start(onError: (error, _) => fail('$error'));
    addTearDown(repository.close);
    final draft = await repository.queue.save(
      requestId: newLocalId(),
      idempotencyKey: newLocalId(),
      body: helpRequestPayload,
    );
    final id = draft.resourceId;
    final updates = StreamIterator(repository.watch(id));
    addTearDown(updates.cancel);
    expect(await updates.moveNext(), isTrue);
    expect(updates.current?.savedOnPhone, isTrue);
    final closingUpdate = updates.moveNext();
    expect(await opened.future, id);
    var attempts = 0;
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          attempts++;
          drop(request, handler);
        },
      ),
    );
    await expectLater(connector.uploadData(local.database), throwsStateError);

    final closedAt = now.add(const Duration(minutes: 3)).toIso8601String();
    const reason = 'Derivado al servicio oficial';
    await local.database.writeTransaction((tx) async {
      await tx.execute('INSERT INTO ps_data__mis_pedidos_ayuda (id, data) VALUES (?, ?)', [
        id,
        jsonEncode({
          'estado': 'derivado',
          'version': 4,
          'creado_en': now.toIso8601String(),
          'cerrado_en': closedAt,
        }),
      ]);
      await tx.execute('INSERT INTO ps_data__historial_mis_pedidos (id, data) VALUES (?, ?)', [
        '4',
        jsonEncode({
          'pedido_id': id,
          'hasta': 'derivado',
          'ocurrido_en': closedAt,
          'motivo': reason,
        }),
      ]);
    });
    expect(await closingUpdate, isTrue);
    // The failed attempt may cause an extra emission before the synced rows arrive.
    while (updates.current?.latest == null) {
      expect(await updates.moveNext(), isTrue);
    }
    expect(updates.current?.latest?.stage, HelpRequestStage.referred);
    expect(updates.current?.latest?.version, 4);
    expect(updates.current?.latest?.reason, reason);
    await unsubscribed.future;
    expect(await updates.moveNext(), isFalse);
    await local.database.execute('DELETE FROM ps_data__mis_pedidos_ayuda WHERE id = ?', [id]);
    await local.database.execute("DELETE FROM ps_data__historial_mis_pedidos WHERE id = '4'");
    await reopen();
    final reopened = OwnHelpRequestRepository(
      local,
      subscribe: (_) async {
        fail('Un pedido cerrado no debe abrir el stream');
      },
    );
    expect((await reopened.watch(id).first)?.latest?.reason, reason);
    await connector.uploadData(local.database);
    expect(attempts, 1);
    expect(await local.database.getNextCrudTransaction(), isNull);
  });
}
