import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/dev_sync_app.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';
import 'package:vecinal/features/solidaridad/data/powersync_post_repository.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('cerrar la sesión de prueba sin red elimina los datos y vuelve al inicio', (
    tester,
  ) async {
    final directory = await (await getTemporaryDirectory()).createTemp('vecinal-sign-out-');
    addTearDown(() => directory.delete(recursive: true));
    final store = InMemorySecureStore();
    final app = await _seed(directory, store);

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Publicación sintética pendiente'), findsOneWidget);
    await tester.tap(find.byTooltip('Cerrar sesión de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Publicación sintética pendiente'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar sesión de prueba'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cerrar sesión de prueba'));
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión de prueba'), findsOneWidget);
    await _expectPurged(directory, store);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión de prueba'), findsOneWidget);
    expect(find.text('Muro de favores'), findsNothing);
    await _expectPurged(directory, store);
  });

  testWidgets('al reiniciar termina la purga pendiente antes de mostrar la app', (tester) async {
    final directory = await (await getTemporaryDirectory()).createTemp('vecinal-sign-out-pending-');
    addTearDown(() => directory.delete(recursive: true));
    final store = InMemorySecureStore();
    final app = await _seed(directory, store);
    await store.write('vecinal.dev-session.signed-out', '1');

    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(find.text('Iniciar sesión de prueba'), findsOneWidget);
    expect(find.text('Muro de favores'), findsNothing);
    await _expectPurged(directory, store);
  });
}

Future<DevSyncApp> _seed(Directory directory, SecureStore store) async {
  const session = LocalSession.demo;
  final wall = await LocalSyncDatabase.open(
    path: path.join(directory.path, 'vecinal-demo.db'),
    store: store,
    accountId: session.neighborId,
  );
  final posts = PowerSyncPostRepository(
    wall.database,
    neighborId: session.neighborId,
    zoneId: session.zoneId,
  );
  await posts.publish(
    const NewPost(
      type: PostType.lend,
      category: 'prueba',
      title: 'Publicación sintética pendiente',
    ),
  );
  await wall.close();
  final cases = await LocalSyncDatabase.open(
    path: path.join(directory.path, 'vecinal-demo-cases.db'),
    store: store,
    accountId: 'cases.${session.neighborId}',
    schema: assignedCaseSchema,
  );
  await cases.database
      .execute('INSERT INTO pedidos_ayuda (id, detalle, vence_en) VALUES (?, ?, ?)', [
        'caso-sintetico',
        'Detalle de prueba',
        DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      ]);
  await cases.close();
  return DevSyncApp(
    environment: const AppEnvironment(apiBaseUrl: 'http://127.0.0.1:1', powersyncUrl: ''),
    directory: directory.path,
    store: store,
  );
}

Future<void> _expectPurged(Directory directory, SecureStore store) async {
  const account = LocalSession.demo;
  expect(await directory.list().toList(), isEmpty);
  expect(await store.read('powersync.database.${account.neighborId}'), isNull);
  expect(await store.read('powersync.database.cases.${account.neighborId}'), isNull);
}
