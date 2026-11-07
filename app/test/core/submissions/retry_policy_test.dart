import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/submissions/retry_policy.dart';

void main() {
  const policy = RetryPolicy(base: Duration(seconds: 2), max: Duration(minutes: 5));

  test('la espera nunca supera el techo exponencial del intento', () {
    final random = Random(42);
    for (var attempt = 1; attempt <= 12; attempt++) {
      final ceiling = min(2000 * pow(2, attempt - 1), 300000).toInt();
      for (var sample = 0; sample < 50; sample++) {
        final delay = policy.delayFor(attempt, random).inMilliseconds;
        expect(delay, inInclusiveRange(0, ceiling));
      }
    }
  });

  test('reparte los reintentos: no todos los celulares esperan lo mismo', () {
    final random = Random(7);
    final delays = {for (var i = 0; i < 100; i++) policy.delayFor(5, random).inMilliseconds};
    expect(delays.length, greaterThan(50));
  });

  test('se detiene en el máximo aunque el intento sea muy alto', () {
    final delay = policy.delayFor(1000, Random(1));
    expect(delay, lessThanOrEqualTo(const Duration(minutes: 5)));
  });

  test('el primer reintento es el número 1', () {
    expect(() => policy.delayFor(0, Random()), throwsArgumentError);
  });
}
