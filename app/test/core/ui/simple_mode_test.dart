import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/ui/simple_mode.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('arranca desactivado por defecto', () async {
    final container = ProviderContainer();
    final mode = await container.read(simpleModeProvider.future);
    expect(mode, isFalse);
    container.dispose();
  });

  test('toggle activa y desactiva el modo sencillo', () async {
    final container = ProviderContainer();
    final notifier = container.read(simpleModeProvider.notifier);

    expect(await container.read(simpleModeProvider.future), isFalse);

    await notifier.toggle();
    expect(await container.read(simpleModeProvider.future), isTrue);

    await notifier.toggle();
    expect(await container.read(simpleModeProvider.future), isFalse);

    container.dispose();
  });

  test('persiste en shared_preferences', () async {
    SharedPreferences.setMockInitialValues({'simple_mode': true});

    final container = ProviderContainer();
    expect(await container.read(simpleModeProvider.future), isTrue);
    container.dispose();
  });

  test('set fuerza un valor y lo persiste', () async {
    final container = ProviderContainer();
    final notifier = container.read(simpleModeProvider.notifier);

    await notifier.set(true);
    expect(await container.read(simpleModeProvider.future), isTrue);

    // Nuevo contenedor lee el valor persistido.
    final container2 = ProviderContainer();
    expect(await container2.read(simpleModeProvider.future), isTrue);
    container2.dispose();

    container.dispose();
  });

  test('sube el texto un 30 % sin pasar del 200 %, salvo que el teléfono ya pida más', () {
    expect(simpleModeScale(1), closeTo(1.3, 1e-9));
    expect(simpleModeScale(1.5), closeTo(1.95, 1e-9));
    expect(simpleModeScale(1.8), simpleModeMaxTextScale);
    expect(simpleModeScale(2), 2);
    expect(simpleModeScale(2.5), 2.5);
  });

  testWidgets('agranda el texto de lo que tiene debajo sin perder lo escrito', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          builder: (context, child) => SimpleModeScope(child: child!),
          home: const Scaffold(body: TextField()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ana');
    double scale() => MediaQuery.textScalerOf(tester.element(find.byType(TextField))).scale(10);
    expect(scale(), 10);

    await container.read(simpleModeProvider.notifier).set(true);
    await tester.pump();
    expect(scale(), closeTo(13, 1e-9));
    expect(find.text('Ana'), findsOneWidget);

    await container.read(simpleModeProvider.notifier).set(false);
    await tester.pump();
    expect(scale(), 10);
    expect(find.text('Ana'), findsOneWidget);
  });

  testWidgets('en la app agranda todas las pantallas y cambiarlo no las reinicia', (tester) async {
    SharedPreferences.setMockInitialValues({'simple_mode': true});
    await tester.pumpWidget(const ProviderScope(child: VecinalApp()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final container = ProviderScope.containerOf(tester.element(find.byType(VecinalApp)));
    double scale() => MediaQuery.textScalerOf(tester.element(find.byType(NavigationBar))).scale(10);
    expect(scale(), closeTo(13, 1e-9));
    final navigator = tester.state(find.byType(Navigator).first);

    await container.read(simpleModeProvider.notifier).set(false);
    await tester.pumpAndSettle();
    expect(scale(), 10);
    expect(tester.state(find.byType(Navigator).first), same(navigator));
  });
}
