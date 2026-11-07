import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Operating mode of the app (State pattern, sections 3.3 and 7.1).
///
/// It changes the home screen, the menu and the sync priorities.
enum AppMode { normal, emergency, recovery }

/// Transition not allowed by the mode state machine.
class InvalidModeTransition implements Exception {
  const InvalidModeTransition(this.from, this.action);

  final AppMode from;

  /// Spanish description of the attempted action, shown in logs and errors.
  final String action;

  @override
  String toString() => 'No se puede $action desde el modo ${from.name}.';
}

/// Normal → Emergency → Recovery → Normal. An aftershock during recovery goes back to emergency.
extension ModeTransitions on AppMode {
  /// Official alert, zone coordinator or the "Estoy en emergencia" button.
  AppMode activateEmergency() => AppMode.emergency;

  /// End of the event.
  AppMode endEvent() => switch (this) {
    AppMode.emergency => AppMode.recovery,
    _ => throw InvalidModeTransition(this, 'finalizar el evento'),
  };

  /// Every case of the event was closed.
  AppMode closeRecovery() => switch (this) {
    AppMode.recovery => AppMode.normal,
    _ => throw InvalidModeTransition(this, 'cerrar la recuperación'),
  };
}

class AppModeController extends Notifier<AppMode> {
  @override
  AppMode build() => AppMode.normal;

  void activateEmergency() => state = state.activateEmergency();

  void endEvent() => state = state.endEvent();

  void closeRecovery() => state = state.closeRecovery();
}

final appModeProvider = NotifierProvider<AppModeController, AppMode>(AppModeController.new);
