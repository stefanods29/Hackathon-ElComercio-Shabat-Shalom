/// A help request in the zone's queue, minimized: what is needed, how urgent, the public cell and
/// its history. Never the requester's contact data (design, section 4).
library;

enum CasePriority { high, medium, low }

/// Same needs as the app's emergency dashboard.
enum EmergencyNeed { water, food, medicine, transport, shelter, other }

/// States of section 7.2 the console sees (the "saved on the phone" state never reaches the API).
enum CaseStatus {
  sent,
  seen,
  onTheWay,
  attended,
  referred,
  closedUnattended;

  bool get isOpen => this == sent || this == seen || this == onTheWay;
}

/// Official lines a case can be referred to (section 7.4).
enum ReferralLine {
  police('105'),
  firefighters('116'),
  ambulance('106');

  const ReferralLine(this.number);

  final String number;
}

enum AssigneeKind { brigadist, neighbor }

class CaseAssignee {
  const CaseAssignee({required this.id, required this.displayName, required this.kind});

  final String id;
  final String displayName;
  final AssigneeKind kind;
}

/// One audited change: states, the role that made it, when, and its reason when there is one.
class CaseHistoryEntry {
  const CaseHistoryEntry({
    required this.from,
    required this.to,
    required this.at,
    required this.role,
    this.reason,
  });

  final CaseStatus? from;
  final CaseStatus to;
  final DateTime at;

  /// Role code of whoever made the change (`coordinador`, `brigadista`, `vecino`, `sistema`).
  final String role;
  final String? reason;
}

class ExactLocation {
  const ExactLocation({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class EmergencyCase {
  const EmergencyCase({
    required this.id,
    required this.version,
    required this.priority,
    required this.need,
    required this.status,
    required this.cellLabel,
    required this.createdAt,
    this.unreviewedSince,
    this.assignee,
    this.history = const [],
    this.exactLocation,
  });

  final String id;

  /// Optimistic concurrency: every change sends it back as `versionVista`.
  final int version;
  final CasePriority priority;
  final EmergencyNeed need;
  final CaseStatus status;

  /// Public cell, never the exact point.
  final String cellLabel;
  final DateTime createdAt;

  /// Waiting for its first human review since then; null once a coordinator saw it.
  final DateTime? unreviewedSince;
  final CaseAssignee? assignee;
  final List<CaseHistoryEntry> history;

  /// Only for the assignee while the case is on the way. The API enforces it too.
  final ExactLocation? exactLocation;

  DateTime get updatedAt => history.isEmpty ? createdAt : history.last.at;
}

/// First human review times (section 9.2). Low priority is best effort, with no limit.
class ReviewPolicy {
  const ReviewPolicy({
    this.high = const Duration(minutes: 15),
    this.medium = const Duration(hours: 2),
  });

  final Duration high;
  final Duration medium;

  Duration? limitFor(CasePriority priority) => switch (priority) {
    CasePriority.high => high,
    CasePriority.medium => medium,
    CasePriority.low => null,
  };
}

enum ReviewMark { onTime, aboutToEscalate, overdue }

class ReviewClock {
  const ReviewClock({required this.waited, required this.limit, required this.mark});

  final Duration waited;
  final Duration? limit;
  final ReviewMark mark;

  Duration? get remaining => switch (limit) {
    final Duration value => value - waited,
    null => null,
  };
}

/// "Por escalar" with 25 % of the time or less than 5 minutes left; "fuera de tiempo" once over.
ReviewMark markFor(Duration waited, Duration? limit) {
  if (limit == null) return ReviewMark.onTime;
  if (waited >= limit) return ReviewMark.overdue;
  final remaining = limit - waited;
  if (remaining * 4 <= limit || remaining < const Duration(minutes: 5)) {
    return ReviewMark.aboutToEscalate;
  }
  return ReviewMark.onTime;
}

/// Null once the case had its first review.
ReviewClock? reviewClockOf(EmergencyCase item, DateTime now, ReviewPolicy policy) {
  final since = item.unreviewedSince;
  if (since == null) return null;
  final waited = now.isBefore(since) ? Duration.zero : now.difference(since);
  final limit = policy.limitFor(item.priority);
  return ReviewClock(waited: waited, limit: limit, mark: markFor(waited, limit));
}

/// By priority (high first), then the longest without review first, then the oldest.
List<EmergencyCase> sortQueue(Iterable<EmergencyCase> cases) {
  int compare(EmergencyCase a, EmergencyCase b) {
    final byPriority = a.priority.index.compareTo(b.priority.index);
    if (byPriority != 0) return byPriority;
    final aSince = a.unreviewedSince;
    final bSince = b.unreviewedSince;
    if (aSince != null && bSince != null) return aSince.compareTo(bSince);
    if (aSince != null) return -1;
    if (bSince != null) return 1;
    return a.createdAt.compareTo(b.createdAt);
  }

  return [...cases]..sort(compare);
}

/// What the console can do with a case (section 7.2). "Atendido" is confirmed by the neighbor.
enum CaseAction { markSeen, assign, refer, closeUnattended }

Set<CaseAction> actionsFrom(CaseStatus status) => switch (status) {
  CaseStatus.sent => const {CaseAction.markSeen},
  CaseStatus.seen => const {CaseAction.assign, CaseAction.refer, CaseAction.closeUnattended},
  _ => const {},
};

/// Referring and closing without attending tell the requester why (section 7.2).
bool needsReason(CaseAction action) =>
    action == CaseAction.refer || action == CaseAction.closeUnattended;

CaseStatus resultOf(CaseAction action) => switch (action) {
  CaseAction.markSeen => CaseStatus.seen,
  CaseAction.assign => CaseStatus.onTheWay,
  CaseAction.refer => CaseStatus.referred,
  CaseAction.closeUnattended => CaseStatus.closedUnattended,
};

const reasonMinLength = 3;
const reasonMaxLength = 300;

/// The exact point only for the person assigned, and only while on the way.
bool showsExactLocation(EmergencyCase item, String viewerId) =>
    item.status == CaseStatus.onTheWay &&
    item.assignee?.id == viewerId &&
    item.exactLocation != null;
