import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/l10n/app_localizations.dart';

void main() {
  final now = DateTime.utc(2026, 11, 6, 15);
  final texts = lookupAppLocalizations(const Locale('es'));

  test('usa lenguaje simple y singular/plural correctos', () {
    expect(timeAgo(now.subtract(const Duration(seconds: 30)), now, texts),
        'hace un momento');
    expect(timeAgo(now.subtract(const Duration(minutes: 1)), now, texts),
        'hace 1 minuto');
    expect(timeAgo(now.subtract(const Duration(minutes: 45)), now, texts),
        'hace 45 minutos');
    expect(timeAgo(now.subtract(const Duration(hours: 1)), now, texts),
        'hace 1 hora');
    expect(timeAgo(now.subtract(const Duration(hours: 5)), now, texts),
        'hace 5 horas');
    expect(timeAgo(now.subtract(const Duration(days: 1)), now, texts),
        'hace 1 día');
    expect(timeAgo(now.subtract(const Duration(days: 3)), now, texts),
        'hace 3 días');
  });

  test('una hora futura (reloj desfasado) no muestra tiempos negativos', () {
    expect(timeAgo(now.add(const Duration(minutes: 3)), now, texts),
        'hace un momento');
  });
}
