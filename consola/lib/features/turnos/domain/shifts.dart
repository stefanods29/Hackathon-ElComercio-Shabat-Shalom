import 'package:vecinal_consola/core/session/operator.dart';

/// A coordinator or brigadist of the zone. `active`: the account is enabled for operation.
class ZoneOperator {
  const ZoneOperator({
    required this.id,
    required this.displayName,
    required this.role,
    required this.active,
  });

  final String id;
  final String displayName;
  final OperationalRole role;
  final bool active;
}

enum ShiftState { scheduled, current, finished }

class Shift {
  const Shift({
    required this.id,
    required this.version,
    required this.personId,
    required this.personName,
    required this.role,
    required this.startsAt,
    required this.endsAt,
    this.endedAt,
  });

  final String id;
  final int version;
  final String personId;
  final String personName;
  final OperationalRole role;
  final DateTime startsAt;
  final DateTime endsAt;

  /// Set when someone ended the shift before its time.
  final DateTime? endedAt;

  ShiftState stateAt(DateTime now) {
    final end = endedAt ?? endsAt;
    if (!now.isBefore(end)) return ShiftState.finished;
    if (now.isBefore(startsAt)) return ShiftState.scheduled;
    return ShiftState.current;
  }
}

class ShiftBoard {
  const ShiftBoard({required this.operators, required this.shifts, required this.updatedAt});

  final List<ZoneOperator> operators;
  final List<Shift> shifts;
  final DateTime updatedAt;
}

class ShiftDraft {
  const ShiftDraft({required this.personId, required this.startsAt, required this.endsAt});

  final String personId;
  final DateTime startsAt;
  final DateTime endsAt;
}

enum CoverageGap { tooFewCoordinators, noCurrentShift }

/// Section 9.3: at least two active coordinators and a shift in force for the current event.
class Coverage {
  const Coverage({required this.activeCoordinators, required this.hasCurrentShift});

  static const requiredCoordinators = 2;

  final int activeCoordinators;
  final bool hasCurrentShift;

  List<CoverageGap> get gaps => [
    if (activeCoordinators < requiredCoordinators) CoverageGap.tooFewCoordinators,
    if (!hasCurrentShift) CoverageGap.noCurrentShift,
  ];

  bool get covered => gaps.isEmpty;
}

/// The console only shows the rule; Emergencias (Phase 2, Lot B) decides with 409
/// `zona_sin_cobertura`.
Coverage coverageOf(ShiftBoard board, DateTime now) => Coverage(
  activeCoordinators: board.operators
      .where((person) => person.active && person.role == OperationalRole.coordinator)
      .length,
  hasCurrentShift: board.shifts.any((shift) => shift.stateAt(now) == ShiftState.current),
);

/// Port to the shifts of Phase 2, Lot B (part 3).
abstract interface class ShiftsRepository {
  Future<ShiftBoard> board(String zoneId);

  Future<Shift> create(String zoneId, ShiftDraft draft, {required String idempotencyKey});

  Future<Shift> end(Shift shift, {required String idempotencyKey});
}
