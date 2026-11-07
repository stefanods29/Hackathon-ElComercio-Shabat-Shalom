import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/features/solidaridad/data/in_memory_post_repository.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/domain/post_repository.dart';

final syncedPostRepositoryProvider = Provider<PostRepository?>((ref) => null);

final postRepositoryProvider = Provider<PostRepository>((ref) {
  final synced = ref.watch(syncedPostRepositoryProvider);
  if (synced != null) {
    final practice = ref.watch(practiceModeProvider);
    // Fail closed while preferences load: no real command may escape practice mode.
    if (!practice.hasValue) throw StateError('Cargando el modo práctica.');
    if (practice.value != true) return synced;
  }
  return ref.watch(practicePostRepositoryProvider);
});

/// Wall repository. Lot A swaps it for the PowerSync implementation
/// (encrypted SQLite + upload queue) without touching any screen.
final practicePostRepositoryProvider = Provider<PostRepository>((ref) {
  final session = ref.watch(sessionProvider);
  final now = DateTime.now();
  final repository = InMemoryPostRepository(
    currentNeighborId: session.neighborId,
    zoneId: session.zoneId,
    initial: [
      Post(
        id: '01970000-0000-7000-8000-00000000f001',
        authorId: '01970000-0000-7000-8000-0000000000a1',
        zoneId: session.zoneId,
        type: PostType.lend,
        category: 'herramientas',
        title: 'Presto taladro por la tarde',
        status: PostStatus.open,
        version: 1,
        createdAt: now.subtract(const Duration(hours: 2)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      Post(
        id: '01970000-0000-7000-8000-00000000f002',
        authorId: '01970000-0000-7000-8000-0000000000c1',
        zoneId: session.zoneId,
        type: PostType.need,
        category: 'agua',
        title: 'Necesito dos bidones de agua para mi mamá',
        status: PostStatus.open,
        version: 1,
        createdAt: now.subtract(const Duration(minutes: 20)),
        updatedAt: now.subtract(const Duration(minutes: 20)),
      ),
    ],
  );
  ref.onDispose(repository.close);
  return repository;
});

final wallProvider = StreamProvider<List<Post>>((ref) {
  if (ref.watch(syncedPostRepositoryProvider) != null &&
      !ref.watch(practiceModeProvider).hasValue) {
    return const Stream.empty();
  }
  return ref.watch(postRepositoryProvider).watchWall();
});

/// Acciones que el servidor rechazó para siempre ("acciones por revisar").
final actionsToReviewProvider = StreamProvider<List<Submission>>((ref) {
  if (ref.watch(syncedPostRepositoryProvider) != null &&
      !ref.watch(practiceModeProvider).hasValue) {
    return const Stream.empty();
  }
  return ref.watch(postRepositoryProvider).watchActionsToReview();
});
