import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/features/solidaridad/data/powersync_post_repository.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/presentation/actions_to_review_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

void main() {
  late Directory directory;
  late LocalSyncDatabase local;
  late PowerSyncPostRepository posts;
  const draft = NewPost(
    type: PostType.lend,
    category: 'herramientas',
    title: 'Prueba de publicación',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({'practiceMode': true});
    directory = await Directory.systemTemp.createTemp('integrated-screens-');
    local = await LocalSyncDatabase.open(
      path: '${directory.path}/wall.db',
      store: InMemorySecureStore(),
      accountId: LocalSession.demo.neighborId,
    );
    posts = PowerSyncPostRepository(
      local.database,
      neighborId: LocalSession.demo.neighborId,
      zoneId: LocalSession.demo.zoneId,
    );
  });
  tearDown(() async {
    await local.close();
    await directory.delete(recursive: true);
  });

  test('práctica nunca encola en la base real y al salir recupera el muro cifrado', () async {
    final container = ProviderContainer.test(
      overrides: [syncedPostRepositoryProvider.overrideWithValue(posts)],
    );
    await container.read(practiceModeProvider.future);
    await container.read(postRepositoryProvider).publish(draft);
    expect(await local.database.getNextCrudTransaction(), isNull);
    await container.read(practiceModeProvider.notifier).set(false);
    await container.read(postRepositoryProvider).publish(draft);
    expect(await posts.watchWall().first, hasLength(1));
    expect(await local.database.getNextCrudTransaction(), isNotNull);
    await container.read(practiceModeProvider.notifier).set(true);
    await container.read(postRepositoryProvider).publish(draft);
    expect(await posts.watchWall().first, hasLength(1));
  });

  testWidgets('el rechazo sigue visible con motivo y alternativa aunque el post desaparezca', (
    tester,
  ) async {
    late List<Submission> actions;
    late List<Post> wall;
    await tester.runAsync(() async {
      final submission = await posts.publish(draft);
      final api = createApiClient(
        const AppEnvironment(apiBaseUrl: 'https://api.example.test', powersyncUrl: ''),
        getToken: () async => 'token',
      );
      api.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, handler) {
            handler.resolve(
              Response(
                requestOptions: r,
                statusCode: 409,
                data: {
                  'codigo': 'favor_no_disponible',
                  'title': 'Otro vecino lo tomó primero',
                  'detail': 'Este favor ya fue tomado.',
                  'status': 409,
                },
              ),
            );
          },
        ),
      );
      await VecinalConnector(api).uploadData(local.database);
      api.close();
      expect((await posts.watchActionsToReview().first).single.id, submission.id);
      wall = await posts.watchWall().first;
      actions = await posts.watchActionsToReview().first;
      expect(wall, isEmpty);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          actionsToReviewProvider.overrideWith((ref) => Stream.value(actions)),
          wallProvider.overrideWith((ref) => Stream.value(wall)),
        ],
        child: const MaterialApp(
          locale: Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ActionsToReviewPage(),
        ),
      ),
    );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 150)));
    await tester.pumpAndSettle();
    expect(find.text('Otro vecino lo tomó primero'), findsOneWidget);
    expect(find.text('Este favor ya fue tomado.'), findsOneWidget);
    expect(find.text('Ir al muro'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
