import 'dart:async';

import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/domain/post_repository.dart';

/// In-memory repository with the SAME semantics as Lot A's real one.
///
/// It lets Lot D build the screens in parallel and backs the tests: `recordResponse`
/// simulates what the server would answer to each submission.
class InMemoryPostRepository implements PostRepository {
  InMemoryPostRepository({
    required this.currentNeighborId,
    required this.zoneId,
    DateTime Function()? clock,
    Iterable<Post> initial = const [],
  }) : _clock = clock ?? DateTime.now {
    for (final post in initial) {
      _posts[post.id] = post;
    }
  }

  final String currentNeighborId;
  final String zoneId;
  final DateTime Function() _clock;
  final _posts = <String, Post>{};
  final _submissions = <String, Submission>{};
  final _beforeSubmission = <String, Post>{};
  final _changes = StreamController<void>.broadcast();

  List<Submission> get submissions => List.unmodifiable(_submissions.values);

  @override
  Stream<List<Post>> watchWall() async* {
    yield _wall();
    await for (final _ in _changes.stream) {
      yield _wall();
    }
  }

  @override
  Stream<List<Submission>> watchActionsToReview() async* {
    yield _toReview();
    await for (final _ in _changes.stream) {
      yield _toReview();
    }
  }

  @override
  Future<Submission> publish(NewPost newPost) async {
    final now = _clock();
    final id = newLocalId();
    _posts[id] = Post(
      id: id,
      authorId: currentNeighborId,
      zoneId: zoneId,
      type: newPost.type,
      category: newPost.category,
      title: newPost.title,
      description: newPost.description,
      status: PostStatus.open,
      version: 1,
      createdAt: now,
      updatedAt: now,
      submissionStatus: SubmissionStatus.savedOnPhone,
    );
    return _enqueue(SubmissionKind.publish, id, now);
  }

  @override
  Future<Submission> takeFavor({required String postId, required int seenVersion}) async {
    final current = _posts[postId];
    if (current == null) {
      throw StateError('La publicación $postId no está en el celular.');
    }
    final now = _clock();
    final submission = _enqueue(SubmissionKind.takeFavor, postId, now);
    _beforeSubmission[submission.id] = current;
    // Optimistic change: the neighbor sees the action right away, marked "saved on your phone".
    _posts[postId] = current.copyWith(
      status: PostStatus.inProgress,
      takenById: currentNeighborId,
      updatedAt: now,
      submissionStatus: SubmissionStatus.savedOnPhone,
    );
    _notify();
    return submission;
  }

  /// Simulates the server's answer to a pending submission.
  void recordResponse(String submissionId, AttemptResult result) {
    final submission = _submissions[submissionId];
    if (submission == null) {
      throw StateError('No existe el envío $submissionId.');
    }
    final updated = submission.recordAttempt(result, _clock());
    _submissions[submissionId] = updated;
    final post = _posts[submission.resourceId];
    if (post != null) {
      if (updated.status == SubmissionStatus.couldNotComplete &&
          submission.kind == SubmissionKind.takeFavor) {
        // The server decides: the optimistic change is rolled back.
        final before = _beforeSubmission.remove(submissionId) ?? post;
        _posts[submission.resourceId] = before.copyWith(submissionStatus: updated.status);
      } else {
        _posts[submission.resourceId] = post.copyWith(
          submissionStatus: updated.status,
          version:
              updated.status == SubmissionStatus.sent && submission.kind == SubmissionKind.takeFavor
              ? post.version + 1
              : null,
        );
      }
    }
    _notify();
  }

  Future<void> close() => _changes.close();

  Submission _enqueue(SubmissionKind kind, String resourceId, DateTime now) {
    final submission = Submission(
      id: newLocalId(),
      kind: kind,
      resourceId: resourceId,
      idempotencyKey: newLocalId(),
      createdAt: now,
    );
    _submissions[submission.id] = submission;
    _notify();
    return submission;
  }

  void _notify() => _changes.add(null);

  List<Post> _wall() =>
      _posts.values.where((post) => post.zoneId == zoneId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<Submission> _toReview() => _submissions.values
      .where((submission) => submission.status == SubmissionStatus.couldNotComplete)
      .toList(growable: false);
}
