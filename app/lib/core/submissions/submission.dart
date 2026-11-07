import 'package:vecinal/core/submissions/submission_status.dart';

/// Kind of queued action; it defines which API endpoint receives it.
enum SubmissionKind { publish, takeFavor }

/// A neighbor's action in the local upload queue (the phone's outbox).
class Submission {
  const Submission({
    required this.id,
    required this.kind,
    required this.resourceId,
    required this.idempotencyKey,
    required this.createdAt,
    this.status = SubmissionStatus.savedOnPhone,
    this.attempts = 0,
    this.lastAttemptAt,
    this.sentAt,
    this.rejectionReason,
  });

  final String id;
  final SubmissionKind kind;

  /// Affected resource (e.g. the post id).
  final String resourceId;

  /// UUIDv7 generated once: every retry uses the same key.
  final String idempotencyKey;
  final DateTime createdAt;
  final SubmissionStatus status;
  final int attempts;
  final DateTime? lastAttemptAt;
  final DateTime? sentAt;
  final RejectionReason? rejectionReason;

  /// Records the result of an attempt and returns the updated submission.
  Submission recordAttempt(AttemptResult result, DateTime now) {
    final newStatus = nextStatus(status, result);
    return Submission(
      id: id,
      kind: kind,
      resourceId: resourceId,
      idempotencyKey: idempotencyKey,
      createdAt: createdAt,
      status: newStatus,
      attempts: attempts + 1,
      lastAttemptAt: now,
      sentAt: newStatus == SubmissionStatus.sent ? now : sentAt,
      rejectionReason: result is Rejected ? result.reason : rejectionReason,
    );
  }
}
