import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/features/reputacion/data/in_memory_reputation_repository.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/domain/reputation_repository.dart';

/// Real reputation repository of the signed-in account (PowerSync), overridden by
/// `AuthenticatedApp`; while it is `null` the screens use the in-memory double.
final syncedReputationRepositoryProvider = Provider<ReputationRepository?>((ref) => null);

/// Reputation repository the screens use. In practice mode nothing reaches the real one.
final reputationRepositoryProvider = Provider<ReputationRepository>((ref) {
  final synced = ref.watch(syncedReputationRepositoryProvider);
  if (synced != null) {
    final practice = ref.watch(practiceModeProvider);
    // Fail closed while preferences load: no real command may escape practice mode.
    if (!practice.hasValue) throw StateError('Cargando el modo práctica.');
    if (practice.value != true) return synced;
  }
  return ref.watch(practiceReputationRepositoryProvider);
});

/// In-memory reviews for practice mode and for building the screens without a backend.
final practiceReputationRepositoryProvider = Provider<ReputationRepository>((ref) {
  final repository = InMemoryReputationRepository(
    publishedReviews: [
      Review(
        id: '01970000-0000-7000-8000-00000000e001',
        serviceId: '01970000-0000-7000-8000-00000000d001',
        rating: 5,
        comment: 'Llegó a la hora y dejó todo limpio.',
        status: ReviewStatus.published,
        publishedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ],
  );
  ref.onDispose(repository.close);
  return repository;
});

/// Published reviews of a service.
final publishedReviewsProvider = StreamProvider.family<List<Review>, String>((ref, serviceId) {
  if (!_ready(ref)) return const Stream.empty();
  return ref.watch(reputationRepositoryProvider).watchPublishedReviews(serviceId);
});

/// My reviews in any state.
final myReviewsProvider = StreamProvider<List<Review>>((ref) {
  if (!_ready(ref)) return const Stream.empty();
  return ref.watch(reputationRepositoryProvider).watchMyReviews();
});

/// The Visto Bueno I gave.
final myEndorsementsProvider = StreamProvider<List<Endorsement>>((ref) {
  if (!_ready(ref)) return const Stream.empty();
  return ref.watch(reputationRepositoryProvider).watchMyEndorsements();
});

/// Waits for practice-mode preferences before touching the real repository.
bool _ready(Ref ref) =>
    ref.watch(syncedReputationRepositoryProvider) == null ||
    ref.watch(practiceModeProvider).hasValue;
