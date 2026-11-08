import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/directorio/data/in_memory_service_directory_repository.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

void main() {
  testWidgets('busca sin tildes, tolera un error y filtra útiles en emergencia', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AccessibleTheme.light(),
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DirectoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final query in ['gasfiter', 'GASFitér', 'gasfitdr']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
      expect(find.text('Gasfitero a domicilio'), findsOneWidget);
      expect(find.textContaining('Aproximadamente'), findsOneWidget);
      expect(find.text('Visto Bueno de tu zona: 2'), findsOneWidget);
    }
    // The page also has the image switch of emergency mode (Phase 2, Lot D).
    await tester.tap(find.widgetWithText(FilterChip, 'Útil en emergencia'));
    await tester.pumpAndSettle();
    expect(find.text('Gasfitero a domicilio'), findsOneWidget);
  });

  testWidgets('vacío sin señal explica descargar una vez', (tester) async {
    final directory = InMemoryServiceDirectoryRepository(currentNeighborId: 'me', zoneId: 'zone');
    final sync = FakeSyncService(SyncStatus.initial);
    addTearDown(directory.close);
    addTearDown(sync.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceDirectoryRepositoryProvider.overrideWithValue(directory),
          syncServiceProvider.overrideWithValue(sync),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const DirectoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('conéctate una vez'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
  });
}
