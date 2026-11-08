import 'package:flutter/material.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

String priorityLabel(AppLocalizations l10n, CasePriority priority) => switch (priority) {
  CasePriority.high => l10n.priorityHigh,
  CasePriority.medium => l10n.priorityMedium,
  CasePriority.low => l10n.priorityLow,
};

String needLabel(AppLocalizations l10n, EmergencyNeed need) => switch (need) {
  EmergencyNeed.water => l10n.needWater,
  EmergencyNeed.food => l10n.needFood,
  EmergencyNeed.medicine => l10n.needMedicine,
  EmergencyNeed.transport => l10n.needTransport,
  EmergencyNeed.shelter => l10n.needShelter,
  EmergencyNeed.other => l10n.needOther,
};

String statusLabel(AppLocalizations l10n, CaseStatus status) => switch (status) {
  CaseStatus.sent => l10n.statusSent,
  CaseStatus.seen => l10n.statusSeen,
  CaseStatus.onTheWay => l10n.statusOnTheWay,
  CaseStatus.attended => l10n.statusAttended,
  CaseStatus.referred => l10n.statusReferred,
  CaseStatus.closedUnattended => l10n.statusClosedUnattended,
};

String assigneeKindLabel(AppLocalizations l10n, AssigneeKind kind) => switch (kind) {
  AssigneeKind.brigadist => l10n.roleBrigadist,
  AssigneeKind.neighbor => l10n.roleNeighbor,
};

String actionLabel(AppLocalizations l10n, CaseAction action) => switch (action) {
  CaseAction.markSeen => l10n.actionMarkSeen,
  CaseAction.assign => l10n.actionAssign,
  CaseAction.refer => l10n.actionRefer,
  CaseAction.closeUnattended => l10n.actionCloseUnattended,
};

String actionHelp(AppLocalizations l10n, CaseAction action) => switch (action) {
  CaseAction.markSeen => l10n.actionMarkSeenHelp,
  CaseAction.assign => l10n.actionAssignHelp,
  CaseAction.refer => l10n.actionReferHelp,
  CaseAction.closeUnattended => l10n.actionCloseUnattendedHelp,
};

IconData actionIcon(CaseAction action) => switch (action) {
  CaseAction.markSeen => Icons.visibility_outlined,
  CaseAction.assign => Icons.person_add_alt_1_outlined,
  CaseAction.refer => Icons.call_outlined,
  CaseAction.closeUnattended => Icons.do_not_disturb_on_outlined,
};

String lineLabel(AppLocalizations l10n, ReferralLine line) => switch (line) {
  ReferralLine.police => l10n.linePolice,
  ReferralLine.firefighters => l10n.lineFirefighters,
  ReferralLine.ambulance => l10n.lineAmbulance,
};

/// "Lleva 12 min sin revisar · límite 15 min", or that it was already reviewed.
String reviewText(AppLocalizations l10n, ReviewClock? clock) {
  if (clock == null) return l10n.reviewDone;
  final waited = describeDuration(l10n, clock.waited);
  final limit = clock.limit;
  if (limit == null) return l10n.reviewWaitingNoLimit(waited);
  return l10n.reviewWaitingWithLimit(waited, describeDuration(l10n, limit));
}

/// Badge for the mark, or null when the case is on time.
Widget? reviewBadge(AppLocalizations l10n, ReviewClock? clock) => switch (clock?.mark) {
  ReviewMark.aboutToEscalate => StatusBadge(
    icon: Icons.schedule,
    label: l10n.markAboutToEscalate,
    tone: BadgeTone.warning,
  ),
  ReviewMark.overdue => StatusBadge(
    icon: Icons.report_outlined,
    label: l10n.markOverdue,
    tone: BadgeTone.danger,
  ),
  _ => null,
};
