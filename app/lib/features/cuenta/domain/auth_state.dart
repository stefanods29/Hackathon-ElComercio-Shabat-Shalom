/// Estado de la sesión del vecino (Parte 5 del Lote D).
sealed class AuthState {
  const AuthState();
}

/// El vecino no ha iniciado sesión.
final class SignedOut extends AuthState {
  const SignedOut();
}

/// El vecino inició sesión pero aún no eligió su zona.
final class NeedsZone extends AuthState {
  const NeedsZone(this.user);

  final LocalUser user;
}

/// El vecino tiene sesión activa y zona asignada.
final class SignedIn extends AuthState {
  const SignedIn(this.user);

  final LocalUser user;
}

/// Datos mínimos del vecino autenticado.
final class LocalUser {
  const LocalUser({required this.neighborId, required this.displayName});

  final String neighborId;
  final String displayName;
}
