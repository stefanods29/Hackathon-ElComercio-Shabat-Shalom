import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';

/// Port of the favor wall (Repository pattern + single source of truth).
///
/// The UI only reads from the local database; the network only updates the local database. The
/// PowerSync implementation belongs to Lot A; meanwhile the in-memory one in `data/` is used.
abstract interface class PostRepository {
  /// Posts of the neighbor's zone, from newest to oldest.
  Stream<List<Post>> watchWall();

  /// Saves the post on the phone right away and leaves it in the upload queue.
  Future<Submission> publish(NewPost newPost);

  /// Queues "take favor" with the version the neighbor is looking at.
  Future<Submission> takeFavor({required String postId, required int seenVersion});

  /// Actions the server rejected for good ("acciones por revisar").
  Stream<List<Submission>> watchActionsToReview();
}
