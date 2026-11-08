import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';

/// A change to a case. Each one travels with `versionVista` and an `Idempotency-Key`.
sealed class CaseCommand {
  const CaseCommand();

  CaseAction get action;
}

final class MarkSeen extends CaseCommand {
  const MarkSeen();

  @override
  CaseAction get action => CaseAction.markSeen;
}

final class AssignCase extends CaseCommand {
  const AssignCase({required this.personId, this.note});

  final String personId;
  final String? note;

  @override
  CaseAction get action => CaseAction.assign;
}

final class ReferCase extends CaseCommand {
  const ReferCase({required this.line, required this.reason});

  final ReferralLine line;
  final String reason;

  @override
  CaseAction get action => CaseAction.refer;
}

final class CloseUnattended extends CaseCommand {
  const CloseUnattended({required this.reason});

  final String reason;

  @override
  CaseAction get action => CaseAction.closeUnattended;
}

/// Someone the coordinator can assign: a brigadist or a neighbor of the zone, with their shift.
class AvailablePerson {
  const AvailablePerson({
    required this.id,
    required this.displayName,
    required this.kind,
    required this.onShift,
  });

  final String id;
  final String displayName;
  final AssigneeKind kind;
  final bool onShift;
}

/// Port to the Emergencias module of Phase 2, Lot B. Errors are `ApiProblem` (Problem Details)
/// or `ConnectionProblem`, the same as every other port.
abstract interface class CasesRepository {
  /// Open cases of the zone the API lets this person see (a brigadist: the ones assigned).
  Future<List<EmergencyCase>> queue(String zoneId);

  Future<EmergencyCase> detail(String caseId);

  Future<List<AvailablePerson>> availablePeople(String zoneId);

  Future<EmergencyCase> apply(
    String caseId, {
    required int seenVersion,
    required CaseCommand command,
    required String idempotencyKey,
  });
}
