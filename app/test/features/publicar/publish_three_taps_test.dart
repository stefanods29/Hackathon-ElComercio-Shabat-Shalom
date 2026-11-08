import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/ui/notice_card.dart';

Widget _withOfflineSync(Widget child) {
  final sync = FakeSyncService(SyncStatus(connected: false));
  return ProviderScope(overrides: [syncServiceProvider.overrideWithValue(sync)], child: child);
}

void main() {
  testWidgets(
    'publica en exactamente 3 toques sin señal y vuelve al muro con "Guardado en tu celular"',
    (tester) async {
      await tester.pumpWidget(_withOfflineSync(const ProviderScope(child: VecinalApp())));
      await tester.pumpAndSettle();

      // Estamos en el muro.
      expect(find.text('Muro de favores'), findsOneWidget);

      // Toque 1: botón "+" del muro.
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Ahora estamos en la pantalla de elegir tipo.
      expect(find.text('Elige qué quieres publicar'), findsOneWidget);

      // Toque 2: elegir un tipo (primer botón de la lista).
      await tester.tap(find.text('OFREZCO').first);
      await tester.pumpAndSettle();

      // Ahora estamos en el formulario de publicar.
      expect(find.text('Publicar', skipOffstage: false), findsAtLeastNWidgets(1));

      // Toque 3: tocar "Publicar" (el botón del formulario, no el título del AppBar).
      final publishButton = find.widgetWithText(FilledButton, 'Publicar');
      expect(publishButton, findsOneWidget);
      await tester.tap(publishButton);
      await tester.pumpAndSettle();

      // Vuelve al muro y ve la publicación con "Guardado en tu celular" (NoticeCard destacado).
      expect(find.text('Muro de favores'), findsOneWidget);
      expect(find.byType(NoticeCard), findsOneWidget);
    },
  );

  testWidgets('título muy corto no se guarda y muestra error junto al campo', (tester) async {
    await tester.pumpWidget(_withOfflineSync(const ProviderScope(child: VecinalApp())));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    await tester.tap(find.text('OFREZCO').first);
    await tester.pumpAndSettle();

    // Borrar el título sugerido y poner uno de 2 letras.
    final titleField = find.byType(TextFormField).first;
    await tester.tap(titleField);
    await tester.pumpAndSettle();
    await tester.enterText(titleField, 'ab');

    await tester.tap(find.widgetWithText(FilledButton, 'Publicar'));
    await tester.pumpAndSettle();

    // Sigue en el formulario, con error junto al campo.
    expect(find.text('El título debe tener entre 3 y 120 caracteres.'), findsOneWidget);
    expect(find.text('Muro de favores'), findsNothing);
  });
}
