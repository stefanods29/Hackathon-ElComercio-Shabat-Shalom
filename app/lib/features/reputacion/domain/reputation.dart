import 'package:vecinal/core/submissions/submission_status.dart';

/// Review states of the contract (`reputacion.resenas.estado`).
enum ReviewStatus {
  inReview('en_revision'),
  published('publicada'),
  hidden('oculta');

  const ReviewStatus(this.apiValue);

  final String apiValue;

  static ReviewStatus fromApi(String value) => values.firstWhere(
    (status) => status.apiValue == value,
    orElse: () => throw FormatException('Estado de reseña desconocido: $value'),
  );
}

/// Variants of a photo published by the CDN (Lot C): `<CDN>/media/<archivoId>/<variante>.webp`.
enum PhotoVariant {
  thumbnail('miniatura'),
  large('grande');

  const PhotoVariant(this.apiValue);

  final String apiValue;
}

/// A photo of a published review. Only public ids travel; never signed URLs.
class ReviewPhoto {
  const ReviewPhoto({
    required this.id,
    required this.reviewId,
    required this.fileId,
    required this.order,
    this.width,
    this.height,
    this.blurhash,
  });

  final String id;
  final String reviewId;
  final String fileId;
  final int order;
  final int? width;
  final int? height;
  final String? blurhash;

  /// Public URL of the photo in the CDN of the environment.
  Uri urlFor(String cdnBaseUrl, [PhotoVariant variant = PhotoVariant.thumbnail]) {
    final base = cdnBaseUrl.endsWith('/')
        ? cdnBaseUrl.substring(0, cdnBaseUrl.length - 1)
        : cdnBaseUrl;
    return Uri.parse('$base/media/$fileId/${variant.apiValue}.webp');
  }
}

/// A review. Published reviews of other neighbors never say who wrote them.
class Review {
  const Review({
    required this.id,
    required this.serviceId,
    required this.rating,
    required this.status,
    this.comment,
    this.statusReason,
    this.createdAt,
    this.publishedAt,
    this.photos = const [],
    this.isMine = false,
    this.submissionStatus = SubmissionStatus.sent,
  });

  final String id;
  final String serviceId;

  /// 1 to 5 stars.
  final int rating;
  final String? comment;
  final ReviewStatus status;

  /// Public code that explains why a review of mine was hidden, if any.
  final String? statusReason;
  final DateTime? createdAt;
  final DateTime? publishedAt;
  final List<ReviewPhoto> photos;
  final bool isMine;
  final SubmissionStatus submissionStatus;
}

/// A Visto Bueno I gave.
class Endorsement {
  const Endorsement({
    required this.serviceId,
    this.createdAt,
    this.submissionStatus = SubmissionStatus.sent,
  });

  final String serviceId;
  final DateTime? createdAt;
  final SubmissionStatus submissionStatus;
}

/// What the neighbor writes on the review screen.
class NewReview {
  const NewReview({
    required this.serviceId,
    required this.rating,
    this.comment,
    this.photoFileIds = const [],
  });

  final String serviceId;
  final int rating;
  final String? comment;

  /// `archivoId` of the photos (Lot C); at most 3.
  final List<String> photoFileIds;
}

/// Content that can be reported (`moderacion.denuncias.tipo_contenido`).
enum ReportedContent {
  post('publicacion'),
  review('resena'),
  service('servicio'),
  photo('foto'),
  provider('proveedor');

  const ReportedContent(this.apiValue);

  final String apiValue;
}

/// Closed list of report reasons of the contract.
enum ReportReason {
  spam('spam'),
  offensive('ofensivo'),
  falseInformation('informacion_falsa'),
  personalData('datos_personales'),
  dangerous('peligroso'),
  other('otro');

  const ReportReason(this.apiValue);

  final String apiValue;
}

/// A report of content that does not belong in the app.
class NewReport {
  const NewReport({
    required this.content,
    required this.contentId,
    required this.reason,
    this.detail,
  });

  final ReportedContent content;
  final String contentId;
  final ReportReason reason;

  /// Optional, up to 500 characters.
  final String? detail;
}
