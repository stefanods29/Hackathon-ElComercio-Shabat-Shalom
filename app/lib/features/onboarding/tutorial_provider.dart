import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bandera de si el vecino ya vio el tutorial. Persistido en `shared_preferences`.
final tutorialSeenProvider = AsyncNotifierProvider<TutorialSeenNotifier, bool>(
  TutorialSeenNotifier.new,
);

class TutorialSeenNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('tutorialSeen') ?? false;
  }

  /// Marca el tutorial como visto y lo persiste.
  Future<void> markSeen() async {
    state = const AsyncData(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorialSeen', true);
  }

  /// Reinicia para que el tutorial vuelva a mostrarse (útil en pruebas).
  Future<void> reset() async {
    state = const AsyncData(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorialSeen', false);
  }
}
