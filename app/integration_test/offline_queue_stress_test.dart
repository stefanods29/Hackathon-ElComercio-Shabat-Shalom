import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/features/solidaridad/data/powersync_post_repository.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const userId = String.fromEnvironment('TEST_STRESS_ACCOUNT_ID');
  const zoneId = String.fromEnvironment('TEST_STRESS_ZONE_ID');
  const operations = 500;

  testWidgets(
    'la cola de 500 publicaciones sintéticas sobrevive al cierre y se sincroniza',
    (_) async {
      final environment = AppEnvironment.fromDefines();
      final publicApi = createApiClient(environment, getToken: () async => null);
      addTearDown(publicApi.close);
      final login = await publicApi.post<Map<String, Object?>>(
        '/v1/dev/sesiones',
        data: {'telefono': '+51900000442'},
      );
      expect(login.statusCode, 201);
      final user = login.data!['usuario'] as Map<String, Object?>;
      expect(user['id'], userId);
      expect(user['zonaId'], zoneId);
      expect(user['nombreVisible'], 'Cuenta sintética de carga');
      final token = login.data!['tokenDeAcceso'] as String;
      final api = createApiClient(environment, getToken: () async => token);
      addTearDown(api.close);

      final directory = await (await getTemporaryDirectory()).createTemp('vecinal-queue-android-');
      final dbPath = path.join(directory.path, 'queue.db');
      const store = SystemSecureStore();
      final scope = 'android-stress-$userId';
      addTearDown(() async {
        await LocalSyncDatabase.discard(path: dbPath, store: store, accountId: scope);
        await directory.delete(recursive: true);
      });
      Future<LocalSyncDatabase> open() async {
        final local = await LocalSyncDatabase.open(path: dbPath, store: store, accountId: scope);
        addTearDown(local.close);
        return local;
      }

      final offline = await open();
      final posts = PowerSyncPostRepository(offline.database, neighborId: userId, zoneId: zoneId);
      final watch = Stopwatch()..start();
      for (var i = 1; i <= operations; i++) {
        await posts.publish(
          NewPost(type: PostType.lend, category: 'prueba', title: 'Operación sintética $i'),
        );
      }
      expect((await offline.database.getUploadQueueStats()).count, operations);
      expect((await posts.watchWall().first).length, operations);
      final enqueueMs = watch.elapsedMilliseconds;
      await offline.close();

      final online = await open();
      final db = online.database;
      expect((await db.getUploadQueueStats()).count, operations);
      final connector = VecinalConnector(
        api,
        endpointOverride: environment.powersyncUrl.isEmpty ? null : environment.powersyncUrl,
      );
      watch.reset();
      await db.connect(connector: connector);
      await db
          .watch('SELECT count(*) AS count FROM ps_crud')
          .firstWhere((rows) => rows.single['count'] == 0)
          .timeout(const Duration(minutes: 6));
      final uploadMs = watch.elapsedMilliseconds;
      final states = await db.getAll(
        'SELECT estado, count(*) AS count FROM envios GROUP BY estado',
      );
      expect(states, [
        {'estado': 'sent', 'count': operations},
      ]);
      await db.waitForFirstSync().timeout(const Duration(seconds: 40));
      final wall = PowerSyncPostRepository(db, neighborId: userId, zoneId: zoneId);
      final received = await wall
          .watchWall()
          .firstWhere((rows) => rows.length == operations)
          .timeout(const Duration(seconds: 40));
      expect(received.map((post) => post.id).toSet(), hasLength(operations));
      debugPrint('VECINAL_TEST_QUEUE $operations $enqueueMs $uploadMs');
    },
    skip: userId.isEmpty || zoneId.isEmpty,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
