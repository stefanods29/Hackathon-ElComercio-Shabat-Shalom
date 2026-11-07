import 'package:vecinal/core/submissions/submission_status.dart';

/// Types of the favor wall. [apiValue] is the value of the API (`contracts/openapi.yaml`) and of
/// the local database; it is also the label the neighbor sees.
enum PostType {
  offer('ofrezco'),
  need('necesito'),
  lend('presto'),
  donate('dono'),
  exchange('intercambio'),
  ride('movilidad');

  const PostType(this.apiValue);

  final String apiValue;

  static PostType fromApi(String value) => values.firstWhere(
    (type) => type.apiValue == value,
    orElse: () => throw FormatException('Tipo de publicación desconocido: $value'),
  );
}

/// Favor statuses: open → in progress → resolved (or cancelled).
enum PostStatus {
  open('abierta'),
  inProgress('en_curso'),
  resolved('resuelta'),
  cancelled('cancelada');

  const PostStatus(this.apiValue);

  /// Value in the API and in the local database.
  final String apiValue;

  static PostStatus fromApi(String value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw FormatException('Estado de publicación desconocido: $value'),
  );
}

/// A wall post as the phone sees it (read from the local database).
class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.zoneId,
    required this.type,
    required this.category,
    required this.title,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.takenById,
    this.submissionStatus = SubmissionStatus.sent,
  });

  final String id;
  final String authorId;
  final String zoneId;
  final PostType type;
  final String category;
  final String title;
  final String? description;
  final PostStatus status;
  final String? takenById;

  /// Version the neighbor is looking at; it travels to the server when taking the favor.
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Status of the last local change of this post (section 3.4).
  final SubmissionStatus submissionStatus;

  bool get isAvailable => status == PostStatus.open;

  Post copyWith({
    PostStatus? status,
    String? takenById,
    int? version,
    DateTime? updatedAt,
    SubmissionStatus? submissionStatus,
  }) {
    return Post(
      id: id,
      authorId: authorId,
      zoneId: zoneId,
      type: type,
      category: category,
      title: title,
      description: description,
      status: status ?? this.status,
      takenById: takenById ?? this.takenById,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submissionStatus: submissionStatus ?? this.submissionStatus,
    );
  }
}

/// What the neighbor fills in on the third tap of the publishing flow.
class NewPost {
  const NewPost({
    required this.type,
    required this.category,
    required this.title,
    this.description,
  });

  final PostType type;
  final String category;
  final String title;
  final String? description;
}
