import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/di/providers.dart';
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
    await tester.ensureVisible(publish);
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
  });
}
