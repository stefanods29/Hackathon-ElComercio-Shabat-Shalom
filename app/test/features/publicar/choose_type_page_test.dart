import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/publicar/domain/suggestions.dart';
import 'package:vecinal/features/publicar/presentation/choose_type_page.dart';
import 'package:vecinal/features/publicar/presentation/publish_form_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

void main() {
  const scenarios = [
    (Size(320, 700), 1.0, false, Brightness.dark),
    (Size(360, 700), 1.0, false, Brightness.light),
    (Size(393, 700), 1.0, false, Brightness.dark),
    (Size(412, 700), 1.0, false, Brightness.light),
    (Size(375, 700), 1.3, true, Brightness.dark),
    (Size(360, 640), 1.5, false, Brightness.light),
    (Size(320, 700), 2.0, false, Brightness.dark),
    (Size(700, 320), 2.0, true, Brightness.light),
  ];

  for (final (size, textScale, simpleMode, brightness) in scenarios) {
    testWidgets('Publicar sin desbordes a ${size.width}×${size.height} dp, texto ×$textScale '
        'y tema ${brightness.name}', (tester) async {
      SharedPreferences.setMockInitialValues({'simple_mode': simpleMode});
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: brightness == Brightness.dark ? AccessibleTheme.dark() : AccessibleTheme.light(),
            locale: const Locale('es'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: const ChooseTypePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Ofrezco un servicio',
        for (final suggestion in publishSuggestions) suggestion.type.apiValue.toUpperCase(),
      ]) {
        final tile = find.widgetWithText(Card, label);
        await tester.scrollUntilVisible(tile, 150);
        await tester.pumpAndSettle();
        expect(tile.hitTestable(), findsOneWidget);
        final tapSize = tester.getSize(tile);
        expect(tapSize.width, greaterThanOrEqualTo(48));
        expect(tapSize.height, greaterThanOrEqualTo(48));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('las seis opciones abren su formulario sugerido y permiten volver', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: VecinalApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    for (final suggestion in publishSuggestions) {
      final tile = find.widgetWithText(Card, suggestion.type.apiValue.toUpperCase());
      await tester.scrollUntilVisible(tile, 150);
      await tester.pumpAndSettle();
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(find.byType(PublishFormPage), findsOneWidget);
      expect(
        tester.widget<EditableText>(find.byType(EditableText).first).controller.text,
        suggestion.title,
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(ChooseTypePage), findsOneWidget);
    }
  });
}
