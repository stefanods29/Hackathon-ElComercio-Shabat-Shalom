import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo sencillo: menos opciones visibles, textos más grandes y acciones principales
/// destacadas. Persistido en `shared_preferences`.
///
/// Se activa desde el menú de la barra superior del muro.
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

/// Scales text on top of the system's (possibly nonlinear) Dynamic Type curve.
TextScaler simpleModeScaler(TextScaler systemScaler, bool enabled) =>
    enabled ? _MultipliedTextScaler(systemScaler, simpleModeTextScale) : systemScaler;

final class _MultipliedTextScaler implements TextScaler {
  const _MultipliedTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize) * factor;

  @override
  TextScaler clamp({double minScaleFactor = 0, double maxScaleFactor = double.infinity}) =>
      _MultipliedTextScaler(
        base.clamp(
          minScaleFactor: minScaleFactor / factor,
          maxScaleFactor: maxScaleFactor / factor,
        ),
        factor,
      );

  // Flutter still requires this compatibility getter on TextScaler.
  // ignore: deprecated_member_use
  @override
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _MultipliedTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}
