/// Moderation queue of Phase 1, Lot B (part 5), consumed as it is: `GET /v1/moderacion/casos`
/// and `POST /v1/moderacion/casos/{id}/decision`, role `moderador`. No contact data.
library;

enum ModerationState {
  pending('pendiente'),
  resolved('resuelto');

  const ModerationState(this.code);

  final String code;
}

enum ModerationAction {
  publish('publicar'),
  hide('ocultar'),
  restore('restaurar'),
  dismiss('descartar'),
  sanction('sancionar');

  const ModerationAction(this.code);

  final String code;

  static ModerationAction? fromCode(String? code) {
    for (final action in values) {
      if (action.code == code) return action;
    }
    return null;
  }
}

class ModerationCase {
  const ModerationCase({
    required this.id,
    required this.contentType,
    required this.contentId,
    required this.state,
    required this.reasonCode,
    required this.lastAction,
    required this.createdAt,
    required this.updatedAt,
    required this.firstReviewAt,
  });

  final String id;

  /// `publicacion`, `resena`, `servicio`, `foto` or `proveedor`.
  final String contentType;
  final String contentId;
  final ModerationState state;

  /// Code of the reason in the queue (no free text, no contact data).
  final String reasonCode;
  final ModerationAction? lastAction;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? firstReviewAt;
}

class ModerationPage {
  const ModerationPage({required this.cases, required this.nextCursor});

  final List<ModerationCase> cases;
  final String? nextCursor;
}

const decisionReasonMaxLength = 500;

abstract interface class ModerationRepository {
  Future<ModerationPage> list({required ModerationState state, String? cursor});

  Future<ModerationCase> decide(
    String caseId, {
    required ModerationAction action,
    required String reason,
    required String idempotencyKey,
  });
}
