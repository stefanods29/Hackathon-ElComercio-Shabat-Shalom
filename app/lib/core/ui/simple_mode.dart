import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo sencillo: textos más grandes en toda la app, y con ellos botones más altos. Persistido en
/// `shared_preferences`.
///
/// Se activa en Cuenta. [SimpleModeScope] lo aplica una sola vez, en la raíz de la app.
final simpleModeProvider = AsyncNotifierProvider<SimpleModeNotifier, bool>(SimpleModeNotifier.new);

class SimpleModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('simple_mode') ?? false;
  }

  /// Activa o desactiva el modo sencillo y lo persiste.
  Future<void> toggle() async {
    final next = !(state.value ?? false);
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('simple_mode', next);
  }

  /// Forza un valor (útil en pruebas).
  Future<void> set(bool value) async {
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('simple_mode', value);
  }
}

/// Factor de escala de texto en modo sencillo.
const simpleModeTextScale = 1.3;

/// El modo sencillo no lleva el texto más allá del 200 % con el que se prueban las pantallas, salvo
/// que el teléfono ya pida más; nunca lo achica.
const simpleModeMaxTextScale = 2.0;

/// Escala del texto con el modo sencillo, sobre la escala que pide el teléfono.
double simpleModeScale(double phoneScale) => phoneScale >= simpleModeMaxTextScale
    ? phoneScale
    : math.min(phoneScale * simpleModeTextScale, simpleModeMaxTextScale);

/// Agranda el texto de todo lo que tiene debajo mientras el modo sencillo está activo.
///
/// Siempre deja el mismo [MediaQuery], encendido o apagado, para que cambiar el modo no reconstruya
/// las pantallas abiertas ni pierda lo escrito.
class SimpleModeScope extends ConsumerWidget {
  const SimpleModeScope({super.key, required this.child});
  final Widget child;

  /// Tamaño de referencia del texto de lectura: con la escala no lineal de Android, el factor
  /// cambia con el tamaño.
  static const _bodySize = 14.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaQuery.of(context);
    final simple = ref.watch(simpleModeProvider).value == true;
    return MediaQuery(
      data: simple
          ? media.copyWith(
              textScaler: TextScaler.linear(
                simpleModeScale(media.textScaler.scale(_bodySize) / _bodySize),
              ),
            )
          : media,
      child: child,
    );
  }
}
