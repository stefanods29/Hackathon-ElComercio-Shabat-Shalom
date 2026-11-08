import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/features/turnos/domain/shifts.dart';

/// Integration seam for Phase 2, Lot B (part 3).
final operationalShiftsFactoryProvider = Provider<ShiftsRepository Function(ConsoleApi api)?>(
  (ref) => null,
);

final shiftsRepositoryProvider = Provider<ShiftsRepository?>((ref) {
  if (ref.watch(currentOperatorProvider) == null) return null;
  if (ref.watch(demoDataProvider)) return DemoShiftsRepository(now: ref.watch(clockProvider));
  return ref.watch(operationalShiftsFactoryProvider)?.call(ref.watch(consoleApiProvider));
});

final shiftBoardProvider = FutureProvider.autoDispose<ShiftBoard>((ref) async {
  final repository = ref.watch(shiftsRepositoryProvider);
  final zoneId = ref.watch(currentOperatorProvider)?.zoneId;
  if (repository == null) throw const ModuleNotAvailable();
  if (zoneId == null) {
    return ShiftBoard(operators: const [], shifts: const [], updatedAt: ref.read(clockProvider)());
  }
  return repository.board(zoneId);
});

/// Fictitious zone with a single active coordinator: the coverage rule shows what is missing.
class DemoShiftsRepository implements ShiftsRepository {
  DemoShiftsRepository({required this.now}) {
    final at = now();
    _shifts.add(
      Shift(
        id: '00000000-0000-4000-8000-000000000301',
        version: 1,
        personId: _operators[2].id,
        personName: _operators[2].displayName,
        role: OperationalRole.brigadist,
        startsAt: at.subtract(const Duration(hours: 2)),
        endsAt: at.add(const Duration(hours: 4)),
      ),
    );
    _shifts.add(
      Shift(
        id: '00000000-0000-4000-8000-000000000302',
        version: 2,
        personId: _operators[0].id,
        personName: _operators[0].displayName,
        role: OperationalRole.coordinator,
        startsAt: at.subtract(const Duration(hours: 10)),
        endsAt: at.subtract(const Duration(hours: 2)),
      ),
    );
  }

  final DateTime Function() now;
  final _shifts = <Shift>[];
  final _replies = <String, Shift>{};

  final _operators = const [
    ZoneOperator(
      id: '00000000-0000-4000-8000-000000000311',
      displayName: 'Coordinadora de ejemplo',
      role: OperationalRole.coordinator,
      active: true,
    ),
    ZoneOperator(
      id: '00000000-0000-4000-8000-000000000312',
      displayName: 'Coordinador de ejemplo (sin habilitar)',
      role: OperationalRole.coordinator,
      active: false,
    ),
    ZoneOperator(
      id: '00000000-0000-4000-8000-000000000313',
      displayName: 'Brigadista de ejemplo',
      role: OperationalRole.brigadist,
      active: true,
    ),
  ];

  Future<void> _latency() => Future<void>.delayed(const Duration(milliseconds: 250));

  @override
  Future<ShiftBoard> board(String zoneId) async {
    await _latency();
    final shifts = [..._shifts]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return ShiftBoard(operators: _operators, shifts: shifts, updatedAt: now());
  }

  @override
  Future<Shift> create(String zoneId, ShiftDraft draft, {required String idempotencyKey}) async {
    await _latency();
    final replay = _replies[idempotencyKey];
    if (replay != null) return replay;
    final person = _operators.where((p) => p.id == draft.personId).firstOrNull;
    if (person == null || !person.active) throw demoProblem(422, 'no_procesable');
    if (!draft.endsAt.isAfter(draft.startsAt)) throw demoProblem(400, 'validacion');
    final shift = Shift(
      id: newLocalId(),
      version: 1,
      personId: person.id,
      personName: person.displayName,
      role: person.role,
      startsAt: draft.startsAt,
      endsAt: draft.endsAt,
    );
    _shifts.add(shift);
    return _replies[idempotencyKey] = shift;
  }

  @override
  Future<Shift> end(Shift shift, {required String idempotencyKey}) async {
    await _latency();
    final replay = _replies[idempotencyKey];
    if (replay != null) return replay;
    final index = _shifts.indexWhere((s) => s.id == shift.id);
    if (index < 0) throw demoProblem(404, 'recurso_no_encontrado');
    final current = _shifts[index];
    if (current.version != shift.version) throw demoProblem(409, 'conflicto_de_version');
    final ended = Shift(
      id: current.id,
      version: current.version + 1,
      personId: current.personId,
      personName: current.personName,
      role: current.role,
      startsAt: current.startsAt,
      endsAt: current.endsAt,
      endedAt: now(),
    );
    _shifts[index] = ended;
    return _replies[idempotencyKey] = ended;
  }
}
