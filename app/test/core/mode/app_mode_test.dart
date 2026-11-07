import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/mode/app_mode.dart';

void main() {
  test('normal → emergencia → recuperación → normal', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(appModeProvider.notifier);

    expect(container.read(appModeProvider), AppMode.normal);
    controller.activateEmergency();
    expect(container.read(appModeProvider), AppMode.emergency);
    controller.endEvent();
    expect(container.read(appModeProvider), AppMode.recovery);
    controller.closeRecovery();
    expect(container.read(appModeProvider), AppMode.normal);
  });

  test('una réplica durante la recuperación vuelve a emergencia', () {
    expect(AppMode.recovery.activateEmergency(), AppMode.emergency);
  });

  test('las transiciones inválidas se rechazan', () {
    expect(AppMode.normal.endEvent, throwsA(isA<InvalidModeTransition>()));
    expect(AppMode.emergency.closeRecovery, throwsA(isA<InvalidModeTransition>()));
  });
}
