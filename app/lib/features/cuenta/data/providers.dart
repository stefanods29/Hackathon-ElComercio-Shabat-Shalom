import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/cuenta/data/in_memory_auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';

/// Proveedor del repositorio de autenticación. El Lote B lo sobrescribe con la versión real.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = InMemoryAuthRepository();
  ref.onDispose(repository.close);
  return repository;
});

/// Estado de sesión del vecino: SignedOut, NeedsZone o SignedIn.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).watch();
});
