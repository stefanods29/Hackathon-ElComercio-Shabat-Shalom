import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';

enum HelpRequestStage { sent, seen, onTheWay, attended, referred, closedWithoutAssistance }

class HelpRequestHistoryEntry {
  const HelpRequestHistoryEntry({
    required this.requestId,
    required this.version,
    required this.stage,
    required this.occurredAt,
    this.reason,
    this.nextStep,
  });

  final String requestId;
  final int version;
  final HelpRequestStage stage;
  final DateTime occurredAt;
  final String? reason;
  final String? nextStep;
}

/// Joins the durable upload result with a snapshot of the author's confirmed history.
class OwnHelpRequestState {
  OwnHelpRequestState({
    required String requestId,
    Submission? submission,
    Iterable<HelpRequestHistoryEntry> history = const [],
  }) : _submission =
           submission?.kind == SubmissionKind.helpRequest && submission?.resourceId == requestId
           ? submission
           : null,
       history = List.unmodifiable(
         history.where((entry) => entry.requestId == requestId).toList()
           ..sort((a, b) => a.version.compareTo(b.version)),
       );

  final Submission? _submission;
  final List<HelpRequestHistoryEntry> history;

  HelpRequestHistoryEntry? get latest => history.lastOrNull;

  // A confirmed history row also proves reception if the original HTTP receipt was lost.
  bool get received => latest != null || _submission?.status == SubmissionStatus.sent;

  bool get savedOnPhone => !received && _submission?.status == SubmissionStatus.savedOnPhone;

  DateTime? get sentAt =>
      history.where((entry) => entry.stage == HelpRequestStage.sent).firstOrNull?.occurredAt ??
      _submission?.sentAt;

  RejectionReason? get rejectionReason => received ? null : _submission?.rejectionReason;
}
