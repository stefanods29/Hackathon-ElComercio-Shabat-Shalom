import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/domain/post_repository.dart';

/// Validation done on the phone so we never queue something the server will reject.
class LocalValidationError implements Exception {
  const LocalValidationError(this.message, [this.field]);

  /// Spanish message shown to the neighbor.
  final String message;

  /// Optional field name the error belongs to (`'title'`, `'category'`, `'description'`).
  /// When null, the error is shown as a general message (e.g. a SnackBar).
  final String? field;

  @override
  String toString() => message;
}

/// "Publish on the wall" use case (third tap). Uses the same rules as the server.
class PublishPost {
  const PublishPost(this._posts);

  final PostRepository _posts;

  Future<Submission> execute(NewPost newPost) {
    final title = newPost.title.trim();
    if (title.length < 3 || title.length > 120) {
      throw const LocalValidationError(
        'El título debe tener entre 3 y 120 caracteres.',
        'title',
      );
    }
    final category = newPost.category.trim().toLowerCase();
    if (category.length < 2 || category.length > 40) {
      throw const LocalValidationError('Elige una categoría.', 'category');
    }
    final description = newPost.description?.trim();
    if (description != null && description.length > 2000) {
      throw const LocalValidationError(
        'La descripción no puede pasar de 2000 caracteres.',
        'description',
      );
    }
    return _posts.publish(
      NewPost(
        type: newPost.type,
        category: category,
        title: title,
        description: (description?.isEmpty ?? true) ? null : description,
      ),
    );
  }
}

/// "Take a favor" use case. The server decides whether another neighbor got there first.
class TakeFavor {
  const TakeFavor(this._posts, {required this.currentNeighborId});

  final PostRepository _posts;
  final String currentNeighborId;

  Future<Submission> execute(Post post) {
    if (post.authorId == currentNeighborId) {
      throw const LocalValidationError('No puedes tomar tu propia publicación.');
    }
    if (!post.isAvailable) {
      throw const LocalValidationError('Este favor ya no está disponible.');
    }
    return _posts.takeFavor(postId: post.id, seenVersion: post.version);
  }
}
