import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/features/solidaridad/data/in_memory_post_repository.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart';

void main() {
  const beto = '01970000-0000-7000-8000-0000000000b1';
  const ana = '01970000-0000-7000-8000-0000000000a1';
  const zone = '01970000-0000-7000-8000-000000000001';
  final now = DateTime.utc(2026, 11, 6, 15);

  final anasFavor = Post(
    id: '01970000-0000-7000-8000-00000000f001',
    authorId: ana,
    zoneId: zone,
    type: PostType.need,
    category: 'agua',
    title: 'Necesito bidones de agua',
    status: PostStatus.open,
    version: 1,
    createdAt: now,
    updatedAt: now,
  );

  late InMemoryPostRepository posts;

  setUp(() {
    posts = InMemoryPostRepository(
      currentNeighborId: beto,
      zoneId: zone,
      clock: () => now,
      initial: [anasFavor],
    );
  });

  tearDown(() => posts.close());

  group('PublishPost', () {
    test('sin señal queda "guardado en tu celular" y aparece al instante en el muro', () async {
      final submission = await PublishPost(posts).execute(
        const NewPost(type: PostType.lend, category: ' Herramientas ', title: 'Presto escalera'),
      );
      expect(submission.status, SubmissionStatus.savedOnPhone);

      final wall = await posts.watchWall().first;
      final mine = wall.firstWhere((post) => post.id == submission.resourceId);
      expect(mine.submissionStatus, SubmissionStatus.savedOnPhone);
      expect(mine.category, 'herramientas');
    });

    test('valida en el celular con las mismas reglas que el servidor', () {
      expect(
        () => PublishPost(
          posts,
        ).execute(const NewPost(type: PostType.donate, category: 'ropa', title: 'ab')),
        throwsA(isA<LocalValidationError>()),
      );
    });
  });

  group('TakeFavor', () {
    test('cuando el servidor acepta, pasa a "enviado"', () async {
      final submission = await TakeFavor(posts, currentNeighborId: beto).execute(anasFavor);
      posts.recordResponse(submission.id, const Accepted());

      final wall = await posts.watchWall().first;
      expect(wall.single.submissionStatus, SubmissionStatus.sent);
      expect(wall.single.takenById, beto);
      expect(await posts.watchActionsToReview().first, isEmpty);
    });

    test('si otro vecino lo tomó primero: se deshace el cambio y va a "acciones por revisar"', () async {
      final submission = await TakeFavor(posts, currentNeighborId: beto).execute(anasFavor);
      posts.recordResponse(
        submission.id,
        const Rejected(RejectionReason(code: 'favor_no_disponible', title: 'Conflicto')),
      );

      final wall = await posts.watchWall().first;
      expect(wall.single.status, PostStatus.open);
      expect(wall.single.submissionStatus, SubmissionStatus.couldNotComplete);
      final toReview = await posts.watchActionsToReview().first;
      expect(toReview.single.rejectionReason?.code, 'favor_no_disponible');
    });

    test('un fallo transitorio deja la acción en la cola para reintentar', () async {
      final submission = await TakeFavor(posts, currentNeighborId: beto).execute(anasFavor);
      posts.recordResponse(submission.id, const TransientFailure('sin red'));
      expect(posts.submissions.single.status, SubmissionStatus.savedOnPhone);
      expect(posts.submissions.single.attempts, 1);
    });

    test('el autor no puede tomar su propia publicación', () {
      expect(
        () => TakeFavor(posts, currentNeighborId: ana).execute(anasFavor),
        throwsA(isA<LocalValidationError>()),
      );
    });
  });
}
