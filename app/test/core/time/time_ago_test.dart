import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/time/time_ago.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 15);

  test('usa lenguaje simple y singular/plural correctos', () {
    expect(timeAgo(now.subtract(const Duration(seconds: 30)), now), 'hace un momento');
    expect(timeAgo(now.subtract(const Duration(minutes: 1)), now), 'hace 1 minuto');
    expect(timeAgo(now.subtract(const Duration(minutes: 45)), now), 'hace 45 minutos');
    expect(timeAgo(now.subtract(const Duration(hours: 1)), now), 'hace 1 hora');
    expect(timeAgo(now.subtract(const Duration(hours: 5)), now), 'hace 5 horas');
    expect(timeAgo(now.subtract(const Duration(days: 1)), now), 'hace 1 día');
    expect(timeAgo(now.subtract(const Duration(days: 3)), now), 'hace 3 días');
  });

  test('una hora futura (reloj desfasado) no muestra tiempos negativos', () {
    expect(timeAgo(now.add(const Duration(minutes: 3)), now), 'hace un momento');
  });
}
