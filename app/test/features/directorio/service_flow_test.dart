import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/features/directorio/data/in_memory_service_directory_repository.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';

void main() {
  testWidgets('ofrece en tres toques, guarda perfil antes del servicio sin señal', (tester) async {
    final repository = InMemoryServiceDirectoryRepository(
      currentNeighborId: LocalSession.demo.neighborId,
      zoneId: LocalSession.demo.zoneId,
      categories: const [
        Category(
          id: 'gasfiteria',
          name: 'Gasfitería',
          icon: 'plumbing',
          usefulInEmergency: true,
          order: 1,
        ),
      ],
    );
    final sync = FakeSyncService(SyncStatus.initial);
    addTearDown(repository.close);
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceDirectoryRepositoryProvider.overrideWithValue(repository),
          syncServiceProvider.overrideWithValue(sync),
        ],
        child: const VecinalApp(),
      ),
    );
    await tester.pumpAndSettle();
    var taps = 0;
    await tester.tap(find.byIcon(Icons.add));
    taps++;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ofrezco un servicio'));
    taps++;
    await tester.pumpAndSettle();
    final publish = find.widgetWithText(FilledButton, 'Publicar');
    await tester.scrollUntilVisible(publish, 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(publish);
    taps++;
    await tester.pumpAndSettle();
    expect(taps, 3);
    expect(repository.submissions.map((s) => s.kind), [
      SubmissionKind.upsertProvider,
      SubmissionKind.publishService,
    ]);
    expect(find.text('Guardado en tu celular'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Editar servicio'), 200);
    expect(find.text('Editar servicio'), findsOneWidget);

    await tester.tap(find.text('Editar servicio'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Guardar cambios');
    await tester.scrollUntilVisible(save, 200, scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Ver servicio'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Ofrezco un servicio'), findsOneWidget);
    expect(find.text('Ver servicio'), findsNothing);
  });

  testWidgets('el menú de categorías se alinea con ambos extremos del campo', (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: VecinalApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(VecinalApp)));
    unawaited(container.read(routerProvider).push<void>(Routes.publishService));
    await tester.pumpAndSettle();

    final field = find.byType(DropdownButtonFormField<String>);
    final fieldRect = tester.getRect(field);
    await tester.tap(field);
    await tester.pumpAndSettle();

    final option = find.text('Cuidado de mayores');
    final menu = find.ancestor(of: option, matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(option, 100, scrollable: menu);
    final menuRect = tester.getRect(menu);
    expect(menuRect.left, closeTo(fieldRect.left, 1));
    expect(menuRect.right, closeTo(fieldRect.right, 1));
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(option, findsOneWidget);
  });
}
