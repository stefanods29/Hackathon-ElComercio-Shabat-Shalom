import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/cuenta/data/in_memory_auth_repository.dart';
import 'package:vecinal/features/cuenta/data/in_memory_privacy_repository.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/privacy_repository.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';

final syncedPrivacyRepositoryProvider = Provider<PrivacyRepository?>((ref) => null);
final practicePrivacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  final repository = InMemoryPrivacyRepository(
    displayName: ref.watch(effectiveSessionProvider).displayName,
  );
  ref.onDispose(repository.close);
  return repository;
});
final privacyRepositoryProvider = Provider<PrivacyRepository>((ref) {
  final practice = ref.watch(practiceModeProvider);
  // Unknown preferences must never expose or mutate the real account.
  if (!practice.hasValue) return const UnavailablePrivacyRepository();
  if (practice.value == true) return ref.watch(practicePrivacyRepositoryProvider);
  final real = ref.watch(syncedPrivacyRepositoryProvider);
  if (real != null) return real;
  if (ref.watch(authRepositoryProvider) is InMemoryAuthRepository) {
    return ref.watch(practicePrivacyRepositoryProvider);
  }
  return const UnavailablePrivacyRepository();
});
final privacyDataProvider = StreamProvider<PrivacyData>(
  (ref) => ref.watch(privacyRepositoryProvider).watchData(),
);

/// Any future presence collector must observe this explicit, default-denied gate.
final presenceReportingAllowedProvider = Provider<bool>((ref) {
  if (ref.watch(practiceModeProvider).value != false) return false;
  final data = ref.watch(privacyDataProvider).value;
  return data?.simulated == false && data?.consents[DataPurpose.residencePresence] == true;
});

final practiceAccountRepositoryProvider = Provider<AuthRepository>((ref) {
  final repository = InMemoryAuthRepository();
  ref.onDispose(repository.close);
  return repository;
});

/// Account operations in practice never reach the real authentication repository.
final accountOperationsRepositoryProvider = Provider<AuthRepository?>((ref) {
  final practice = ref.watch(practiceModeProvider);
  if (!practice.hasValue) return null;
  if (practice.value == true) return ref.watch(practiceAccountRepositoryProvider);
  return ref.watch(authRepositoryProvider);
});
