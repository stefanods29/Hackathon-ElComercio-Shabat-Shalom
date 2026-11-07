import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/dev_sync_session.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/powersync_sync_service.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/features/solidaridad/data/powersync_post_repository.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';

void main() {
  test(
    'dos vecinos toman el mismo favor y la segunda cola continúa tras el rechazo',
    () async {
      const environment = AppEnvironment(apiBaseUrl: 'http://127.0.0.1:3000', powersyncUrl: '');
      final directory = await Directory.systemTemp.createTemp('vecinal-powersync-live-');
      addTearDown(() => directory.delete(recursive: true));
      final publicApi = createApiClient(environment, getToken: () async => null);
      addTearDown(publicApi.close);

      Future<
        ({
          Dio api,
          LocalSyncDatabase local,
          PowerSyncPostRepository posts,
          PowerSyncSyncService sync,
        })
      >
      open(String phone) async {
        final response = await publicApi.post<Map<String, Object?>>(
          '/v1/dev/sesiones',
          data: {'telefono': phone},
        );
        expect(response.statusCode, 201);
        final data = response.data!;
        final user = data['usuario'] as Map<String, Object?>;
        final id = user['id'] as String;
        final api = createApiClient(
          environment,
          getToken: phone == '+51900000002'
              ? DevSyncSession(publicApi).getToken
              : () async => data['tokenDeAcceso'] as String,
        );
        addTearDown(api.close);
        final local = await LocalSyncDatabase.open(
          path: path.join(directory.path, '$id.db'),
          store: InMemorySecureStore(),
          accountId: id,
        );
        addTearDown(local.close);
        final connector = VecinalConnector(api);
        addTearDown(connector.stopRefreshing);
        final sync = PowerSyncSyncService(local, connector);
        final posts = PowerSyncPostRepository(
          local.database,
          neighborId: id,
          zoneId: user['zonaId'] as String,
        );
        return (api: api, local: local, posts: posts, sync: sync);
      }

      final ana = await open('+51900000001');
      final beto = await open('+51900000002');
      final carla = await open('+51900000003');
      const favorite = NewPost(
        type: PostType.lend,
        category: 'herramientas',
        title: 'Prueba de cola offline del Lote A',
      );
      final offer = await carla.posts.publish(favorite);
      expect(offer.status, SubmissionStatus.savedOnPhone);
      expect(
        (await carla.posts.watchWall().first).single.submissionStatus,
        SubmissionStatus.savedOnPhone,
      );
      final pending = await carla.sync.watch().first;
      expect(pending.connected, isFalse);
      expect(pending.pendingUploads, 1);
      await carla.sync.connect();
      await carla.posts.watchWall().firstWhere(
        (posts) => posts.any(
          (p) => p.id == offer.resourceId && p.submissionStatus == SubmissionStatus.sent,
        ),
      );
      await carla.local.database.waitForFirstSync();
      expect(await carla.local.database.getOptional('SELECT id FROM zonas'), isNotNull);

      await ana.sync.connect();
      await beto.sync.connect();
      for (final neighbor in [ana, beto]) {
        final posts = await neighbor.posts.watchWall().firstWhere(
          (posts) => posts.any((p) => p.id == offer.resourceId),
        );
        final post = posts.singleWhere((p) => p.id == offer.resourceId);
        await neighbor.local.database.disconnect();
        await neighbor.posts.takeFavor(postId: post.id, seenVersion: post.version);
        final queued = (await neighbor.posts.watchWall().first).singleWhere((p) => p.id == post.id);
        expect(queued.submissionStatus, SubmissionStatus.savedOnPhone);
        expect(queued.status, PostStatus.inProgress);
      }
      final next = await beto.posts.publish(favorite);

      await ana.sync.connect();
      final winner = await ana.posts.watchWall().firstWhere(
        (posts) => posts.any(
          (p) =>
              p.id == offer.resourceId &&
              p.status == PostStatus.inProgress &&
              p.submissionStatus == SubmissionStatus.sent,
        ),
      );
      final taken = winner.singleWhere((p) => p.id == offer.resourceId);

      await beto.sync.connect();
      final rejected = await beto.posts.watchActionsToReview().firstWhere(
        (actions) => actions.isNotEmpty,
      );
      expect(
        rejected.single.rejectionReason!.code,
        anyOf('favor_no_disponible', 'conflicto_de_version'),
      );
      final remaining = await beto.posts.watchWall().firstWhere(
        (posts) =>
            posts.any(
              (p) => p.id == next.resourceId && p.submissionStatus == SubmissionStatus.sent,
            ) &&
            posts.any((p) => p.id == offer.resourceId && p.takenById == taken.takenById),
      );
      expect(
        remaining.singleWhere((p) => p.id == offer.resourceId).submissionStatus,
        SubmissionStatus.couldNotComplete,
      );
    },
    skip: !const bool.fromEnvironment('LIVE_POWERSYNC'),
    timeout: const Timeout(Duration(seconds: 65)),
  );
}
