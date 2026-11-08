import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo práctica: nada de lo que el vecino hace se envía de verdad.
///
/// Mientras está activo, la app usa un `InMemoryPostRepository` aislado que
/// nunca encola envíos reales. Persistido en `shared_preferences`.
final practiceModeProvider = AsyncNotifierProvider<PracticeModeNotifier, bool>(
  PracticeModeNotifier.new,
);

/// True in the demo build (`tool/demo.dart`): it has no server or account, so practice mode is
/// the only mode that works and the neighbor cannot leave it by mistake.
final practiceLockedProvider = Provider<bool>((ref) => false);

class PracticeModeNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('practiceMode') ?? false;
  }

  /// Activa o desactiva el modo práctica y lo persiste.
  Future<void> toggle() async {
    final next = !(state.value ?? false);
    if (!next && ref.read(practiceLockedProvider)) return;
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('practiceMode', next);
  }

  /// Forza un valor (útil en pruebas).
  Future<void> set(bool value) async {
    if (!value && ref.read(practiceLockedProvider)) return;
    state = AsyncData(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('practiceMode', value);
  }
}
