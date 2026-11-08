import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/security/operational_lock.dart';

const prompt = (
  reason: 'Confirma tu identidad',
  title: 'Modo operativo',
  cancel: 'Cancelar',
  deviceCredential: 'Usar código',
);

class _Lock implements OperationalLock {
  bool accepts = false;
  Completer<bool>? pending;
  int cancellations = 0;

  @override
  Future<bool> authenticate(OperationalPrompt prompt) async => pending?.future ?? accepts;

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}

void main() {
  test('cancelar la autenticación mantiene el modo bloqueado', () async {
    var checks = 0;
    final access = OperationalAccess(
      lock: _Lock(),
      clock: DateTime.now,
      beforeReveal: () async => checks++,
      foreground: true,
    );
    addTearDown(access.dispose);
    await access.unlock(prompt);
    expect(access.canReveal, isFalse);
    expect(access.failed, isTrue);
    expect(checks, 0);
  });

  test('al regresar tras el límite exige desbloquear otra vez, sin consultar la red', () async {
    var now = DateTime.utc(2026, 11, 8);
    var checks = 0;
    final access = OperationalAccess(
      lock: _Lock()..accepts = true,
      clock: () => now,
      beforeReveal: () async => checks++,
      foreground: true,
    );
    addTearDown(access.dispose);
    await access.unlock(prompt);
    expect(access.canReveal, isTrue);

    await access.setForeground(false);
    expect(access.canReveal, isFalse);
    now = now.add(const Duration(minutes: 5));
    await access.setForeground(true);
    expect(access.canReveal, isFalse);
    expect(checks, 1);

    await access.unlock(prompt);
    expect(access.canReveal, isTrue);
    expect(checks, 2);
  });

  test('salir de la vista cancela una autenticación pendiente e ignora su resultado', () async {
    final lock = _Lock()..pending = Completer<bool>();
    var checks = 0;
    final access = OperationalAccess(
      lock: lock,
      clock: DateTime.now,
      beforeReveal: () async => checks++,
      foreground: true,
    );
    final pending = access.unlock(prompt);
    access.dispose();
    lock.pending!.complete(true);
    await pending;
    expect(lock.cancellations, 1);
    expect(checks, 0);
  });
}
