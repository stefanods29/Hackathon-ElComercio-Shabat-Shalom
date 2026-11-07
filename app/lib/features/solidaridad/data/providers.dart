import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/features/solidaridad/data/in_memory_post_repository.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/domain/post_repository.dart';

/// Wall repository. Lot A swaps it for the PowerSync implementation
/// (encrypted SQLite + upload queue) without touching any screen.
final postRepositoryProvider = Provider<PostRepository>((ref) {
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

final wallProvider = StreamProvider<List<Post>>(
  (ref) => ref.watch(postRepositoryProvider).watchWall(),
);
