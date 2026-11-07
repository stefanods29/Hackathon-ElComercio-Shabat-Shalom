/// Visible status of every action the neighbor takes on the phone (section 3.4).
enum SubmissionStatus {
  /// It is in the local queue: nobody else has received it yet.
  savedOnPhone,

  /// The server accepted and stored it.
  sent,

  /// The server rejected it for good (e.g. another neighbor already took the favor).
  couldNotComplete;

  /// A final submission is not retried.
  bool get isFinal => this != SubmissionStatus.savedOnPhone;
}

/// Reason for a definitive rejection, as the server explained it (Problem Details).
class RejectionReason {
  const RejectionReason({required this.code, required this.title, this.detail});

  /// Stable code (e.g. `favor_no_disponible`) to pick the alternative we offer.
  final String code;
  final String title;
  final String? detail;

  @override
  bool operator ==(Object other) =>
      other is RejectionReason &&
      other.code == code &&
      other.title == title &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(code, title, detail);
}

/// Result of one attempt to send to the server.
sealed class AttemptResult {
  const AttemptResult();
}

/// 2xx: the server stored the action (includes retries that answer 200).
final class Accepted extends AttemptResult {
  const Accepted();
}

/// Definitive 4xx: retrying would not change the answer.
final class Rejected extends AttemptResult {
  const Rejected(this.reason);

  final RejectionReason reason;
}

/// No network, 5xx, 408 or 429: retried later with exponential backoff.
final class TransientFailure extends AttemptResult {
  const TransientFailure(this.description);

  final String description;
}

/// Submission state machine. A final submission accepts no more attempts.
SubmissionStatus nextStatus(SubmissionStatus current, AttemptResult result) {
  if (current.isFinal) {
    throw StateError('Un envío en estado ${current.name} ya no admite intentos.');
  }
  return switch (result) {
    Accepted() => SubmissionStatus.sent,
    Rejected() => SubmissionStatus.couldNotComplete,
    TransientFailure() => SubmissionStatus.savedOnPhone,
  };
}
