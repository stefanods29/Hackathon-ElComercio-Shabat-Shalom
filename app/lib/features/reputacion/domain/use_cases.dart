import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/domain/reputation_repository.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart' show LocalValidationError;

/// "Escribir una reseña" with the same rules as the server (`reputacion/resenas-y-ranking`).
class WriteReview {
  const WriteReview(this._reputation);

  final ReputationRepository _reputation;

  Future<Submission> execute(NewReview review) {
    if (review.rating < 1 || review.rating > 5) {
      throw const LocalValidationError('Elige de 1 a 5 estrellas.', 'rating');
    }
    final comment = review.comment?.trim();
    if (comment != null && comment.length > 2000) {
      throw const LocalValidationError(
        'El comentario no puede pasar de 2000 caracteres.',
        'comment',
      );
    }
    if (review.photoFileIds.length > 3) {
      throw const LocalValidationError('Puedes agregar hasta 3 fotos.', 'photos');
    }
    return _reputation.writeReview(
      NewReview(
        serviceId: review.serviceId,
        rating: review.rating,
        comment: (comment?.isEmpty ?? true) ? null : comment,
        photoFileIds: review.photoFileIds,
      ),
    );
  }
}

/// "Denunciar" with the closed list of reasons.
class ReportContent {
  const ReportContent(this._reputation);

  final ReputationRepository _reputation;

  Future<Submission> execute(NewReport report) {
    final detail = report.detail?.trim();
    if (detail != null && detail.length > 500) {
      throw const LocalValidationError('El detalle no puede pasar de 500 caracteres.', 'detail');
    }
    return _reputation.report(
      NewReport(
        content: report.content,
        contentId: report.contentId,
        reason: report.reason,
        detail: (detail?.isEmpty ?? true) ? null : detail,
      ),
    );
  }
}
