import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
}
