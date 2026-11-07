import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo sencillo: menos opciones visibles, textos más grandes y acciones principales
/// destacadas. Persistido en `shared_preferences`.
///
/// Se activa desde el menú de la barra superior del muro.
final simpleModeProvider = AsyncNotifierProvider<SimpleModeNotifier, bool>(
  SimpleModeNotifier.new,
);

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
