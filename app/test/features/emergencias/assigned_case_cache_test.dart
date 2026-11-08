import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:powersync/powersync.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';

class OfflineConnector extends PowerSyncBackendConnector {
  @override
  Future<PowerSyncCredentials?> fetchCredentials() async => null;

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {}
}

class TestCaseSubscription implements SyncStreamSubscription {
  TestCaseSubscription(this.database, this.name, this.parameters);

  final PowerSyncDatabase database;
  @override
  final String name;
  @override
  final Map<String, Object?> parameters;
  final firstSync = Completer<void>();
  bool unsubscribed = false;

  @override
  Future<void> waitForFirstSync() => firstSync.future;

  @override
  void unsubscribe() {
    unsubscribed = true;
    if (!firstSync.isCompleted) firstSync.complete();
  }
}

void main() {
  const caseId = 'caso-sintetico';
  const account = 'vecino-ana';
  const summaryKey = 'powersync.database.cases.$account';
  const exactKey = 'powersync.database.cases.exact.$account';
  final expires = DateTime.utc(2026, 11, 8, 6);
  late InMemorySecureStore store;
  late Directory directory;
  late String casePath;
  late DateTime now;
  late DateTime exactExpires;
  late List<String> openings;
  late List<TestCaseSubscription> subscriptions;

  AssignedCaseCache cache({String accountId = account, bool allow = true}) {
    final result = AssignedCaseCache(
      path: path.join(directory.path, '$accountId.db'),
      store: store,
      accountId: accountId,
      connector: OfflineConnector(),
      clock: () => now,
      authorize: allow
          ? (id, scope) async {
              expect(id, caseId);
              openings.add('autoriza:${scope.apiValue}');
              return (
                authorizationId: 'permiso-$accountId-${scope.apiValue}',
                expiresAt: scope == AssignedCaseScope.summary ? expires : exactExpires,
              );
            }
          : null,
      subscribe: (database, stream, params) async {
        openings.add('suscribe:$stream');
        final subscription = TestCaseSubscription(database, stream, params);
        subscriptions.add(subscription);
        return subscription;
      },
    );
    addTearDown(result.close);
    return result;
  }

  Future<void> summary(
    TestCaseSubscription stream, {
    String stage = 'visto',
    int version = 1,
    DateTime? createdAt,
  }) => stream.database.execute(
    'INSERT OR REPLACE INTO ps_data__pedidos_ayuda (id, data) VALUES (?, ?)',
    [
      caseId,
      jsonEncode({
        'necesidad': 'agua',
        'prioridad': 'alta',
        'estado': stage,
        'version': version,
        'celda': 'celda-aproximada',
        'creado_en': (createdAt ?? now).toIso8601String(),
        'vence_en': expires.add(const Duration(minutes: 30)).toIso8601String(),
      }),
    ],
  );

  Future<void> location(TestCaseSubscription stream) =>
      stream.database.execute('INSERT INTO ps_data__ubicaciones_casos (id, data) VALUES (?, ?)', [
        caseId,
        jsonEncode({'descripcion': 'Detalle ficticio', 'lat': -12.01342, 'lng': -77.01342}),
      ]);

  Future<AssignedCaseCache> openExact() async {
    final cases = cache();
    await cases.request(caseId);
    await summary(subscriptions.single, stage: 'en_camino');
    await cases.review();
    await cases.requestExact(caseId);
    await location(subscriptions.last);
    await cases.review();
    expect((await cases.watch().first)?.location?.latitude, -12.01342);
    return cases;
  }

  setUp(() async {
    store = InMemorySecureStore();
    directory = await Directory.systemTemp.createTemp('vecinal-cases-test-');
    casePath = path.join(directory.path, '$account.db');
    now = expires.subtract(const Duration(minutes: 2));
    exactExpires = now.add(const Duration(minutes: 1));
    openings = [];
    subscriptions = [];
    addTearDown(() => directory.delete(recursive: true));
  });

  test('autoriza por alcance antes de suscribirse y exige En camino para la ubicación', () async {
    final cases = cache();
    await cases.request(caseId);
    expect(subscriptions.single.parameters, {
      'pedido_id': caseId,
      'autorizacion_id': 'permiso-$account-resumen',
    });
    await summary(subscriptions.single);
    await cases.review();
    final assigned = await cases.watch().first;
    expect(assigned?.cell, 'celda-aproximada');
    expect(assigned?.location, isNull);
    await expectLater(cases.requestExact(caseId), throwsStateError);
    expect(openings, ['autoriza:resumen', 'suscribe:caso_asignado']);

    await summary(subscriptions.single, stage: 'en_camino', version: 2);
    await cases.review();
    await cases.requestExact(caseId);
    expect(openings, [
      'autoriza:resumen',
      'suscribe:caso_asignado',
      'autoriza:exacta',
      'suscribe:caso_ubicacion_exacta',
    ]);
    final exact = subscriptions.last;
    expect(exact.parameters['autorizacion_id'], 'permiso-$account-exacta');
    await location(exact);
    await cases.review();
    expect((await cases.watch().first)?.location?.description, 'Detalle ficticio');

    await summary(subscriptions.first, stage: 'visto', version: 3);
    await cases.review();
    expect((await cases.watch().first)?.stage, HelpRequestStage.seen);
    expect((await cases.watch().first)?.location, isNull);
    expect(exact.unsubscribed, isTrue);
    expect(await store.read(exactKey), isNull);
    expect(await File('$casePath.exact').exists(), isFalse);
    expect(await File(casePath).exists(), isTrue);
  });

  test('si PowerSync retira solo la ubicación, se borra su caché y queda el resumen', () async {
    final cases = await openExact();
    final exact = subscriptions.last;
    final removed = cases.watch().firstWhere((value) => value?.location == null);
    await exact.database.execute('DELETE FROM ps_data__ubicaciones_casos WHERE id = ?', [caseId]);
    expect((await removed.timeout(const Duration(seconds: 5)))?.cell, 'celda-aproximada');
    await cases.review();
    expect(exact.unsubscribed, isTrue);
    expect(await store.read(exactKey), isNull);
    expect(await File('$casePath.exact').exists(), isFalse);
  });

  test('al reasignar se borran el resumen y la ubicación del celular anterior', () async {
    final former = await openExact();
    final oldSummary = subscriptions.first;
    final oldExact = subscriptions.last;
    final next = cache(accountId: 'vecino-beto');
    await next.request(caseId);
    final newSummary = subscriptions.last;
    await summary(newSummary);
    await next.review();

    final removed = former.watch().firstWhere((value) => value == null);
    await oldSummary.database.execute('DELETE FROM ps_data__pedidos_ayuda WHERE id = ?', [caseId]);
    expect(await removed.timeout(const Duration(seconds: 5)), isNull);
    await former.review();
    expect(oldSummary.unsubscribed, isTrue);
    expect(oldExact.unsubscribed, isTrue);
    expect(await store.read(summaryKey), isNull);
    expect(await store.read(exactKey), isNull);
    expect(await File(casePath).exists(), isFalse);
    expect(await File('$casePath.exact').exists(), isFalse);
    expect((await next.watch().first)?.id, caseId);
    expect(newSummary.unsubscribed, isFalse);
  });

  test('al cerrar el pedido purga ambos archivos y sus claves', () async {
    final cases = await openExact();
    await summary(subscriptions.first, stage: 'atendido', version: 2);
    await cases.review();
    expect(await cases.watch().first, isNull);
    expect(await store.read(summaryKey), isNull);
    expect(await store.read(exactKey), isNull);
    expect(await File(casePath).exists(), isFalse);
    expect(await File('$casePath.exact').exists(), isFalse);
  });

  test('caduca sin conexión por el menor permiso y conserva la cola de la cuenta', () async {
    final wall = await LocalSyncDatabase.open(
      path: path.join(directory.path, 'wall.db'),
      store: store,
      accountId: account,
    );
    addTearDown(wall.close);
    await wall.database.execute("INSERT INTO comandos (id, tipo) VALUES ('test', 'publish')");
    final cases = await openExact();
    now = exactExpires;
    await cases.review();
    expect((await cases.watch().first)?.location, isNull);
    expect(await store.read(exactKey), isNull);
    expect(await store.read(summaryKey), isNotNull);
    now = expires;
    await cases.review();
    expect(await cases.watch().first, isNull);
    expect(await store.read(summaryKey), isNull);
    expect(await File(casePath).exists(), isFalse);
    expect((await wall.database.getUploadQueueStats()).count, 1);
  });

  test('reanuda el resumen vigente y requiere otra apertura para la ubicación', () async {
    final initial = await openExact();
    await initial.close();
    expect(await store.read(exactKey), isNull);
    final restored = cache();
    await restored.restore();
    final cached = await restored.watch().first;
    expect(cached?.id, caseId);
    expect(cached?.location, isNull);
    expect(openings.where((item) => item == 'autoriza:resumen'), hasLength(1));
    expect(subscriptions.last.name, 'caso_asignado');
    await restored.requestExact(caseId);
    expect(openings.where((item) => item == 'autoriza:exacta'), hasLength(2));
  });

  test('al reabrir se purga antes de mostrar un permiso vencido', () async {
    final initial = await openExact();
    await initial.close();
    now = expires;
    final restored = cache();
    await restored.restore();
    expect(await restored.watch().first, isNull);
    expect(await store.read(summaryKey), isNull);
    expect(await File(casePath).exists(), isFalse);
  });

  test('la fecha del caso limita el acceso local aun con permisos vigentes', () async {
    exactExpires = expires;
    final createdAt = now.subtract(const Duration(hours: 23, minutes: 59));
    final cases = cache();
    await cases.request(caseId);
    await summary(subscriptions.single, stage: 'en_camino', createdAt: createdAt);
    await cases.review();
    await cases.requestExact(caseId);
    await location(subscriptions.last);
    await cases.review();
    expect((await cases.watch().first)?.location, isNotNull);

    now = now.add(const Duration(minutes: 1));
    expect(now.isBefore(expires), isTrue);
    expect(await cases.watch().first, isNull);
    await cases.review();
    expect(await store.read(summaryKey), isNull);
    expect(await store.read(exactKey), isNull);
    expect(await File(casePath).exists(), isFalse);
    expect(await File('$casePath.exact').exists(), isFalse);
  });

  test('la reapertura sin red borra el resumen vencido por la edad del caso', () async {
    final createdAt = now.subtract(const Duration(hours: 23, minutes: 59));
    final initial = cache();
    await initial.request(caseId);
    await summary(subscriptions.single, createdAt: createdAt);
    await initial.review();
    expect((await initial.watch().first)?.id, caseId);
    await initial.close();

    now = now.add(const Duration(minutes: 1));
    final restored = cache();
    await restored.restore();
    expect(await restored.watch().first, isNull);
    expect(await store.read(summaryKey), isNull);
    expect(await File(casePath).exists(), isFalse);
    expect(subscriptions, hasLength(1));
  });

  test('sin autorización auditada o después de salir no se abre ningún stream', () async {
    final cases = cache(allow: false);
    await expectLater(cases.request(caseId), throwsStateError);
    expect(subscriptions, isEmpty);
    expect(await File(casePath).exists(), isFalse);

    final active = await openExact();
    await active.wipeForSignOut();
    expect(await active.watch().first, isNull);
    expect(await File(casePath).exists(), isFalse);
    expect(await File('$casePath.exact').exists(), isFalse);
    expect(await store.read(summaryKey), isNull);
    expect(await store.read(exactKey), isNull);
    await expectLater(active.request(caseId), throwsStateError);
  });
}
