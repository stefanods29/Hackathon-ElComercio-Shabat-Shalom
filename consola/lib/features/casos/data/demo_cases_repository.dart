import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/features/casos/domain/cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';

class _DemoCase {
  _DemoCase({
    required this.id,
    required this.priority,
    required this.need,
    required this.status,
    required this.cellLabel,
    required this.createdAt,
    this.unreviewedSince,
    this.assignee,
    this.exactLocation,
    List<CaseHistoryEntry>? history,
  }) : history = history ?? [];

  final String id;
  int version = 1;
  final CasePriority priority;
  final EmergencyNeed need;
  CaseStatus status;
  final String cellLabel;
  final DateTime createdAt;
  DateTime? unreviewedSince;
  CaseAssignee? assignee;
  final ExactLocation? exactLocation;
  final List<CaseHistoryEntry> history;
}

/// Seeded cases of `CONSOLE_DATA=demo`, all fictitious. It applies the rules the API will apply:
/// section 7.2 transitions, `versionVista`, idempotency and the exact location only for the
/// assignee while on the way.
class DemoCasesRepository implements CasesRepository {
  DemoCasesRepository({required this.viewer, required this.now}) {
    _seed();
  }

  final Operator viewer;
  final DateTime Function() now;
  final _cases = <String, _DemoCase>{};
  final _replies = <String, EmergencyCase>{};

  static const _brigadistId = '00000000-0000-4000-8000-000000000201';
  static const _neighborId = '00000000-0000-4000-8000-000000000202';

  late final List<AvailablePerson> _people = [
    AvailablePerson(
      id: viewer.has(OperationalRole.brigadist) ? viewer.id : _brigadistId,
      displayName: 'Brigadista de ejemplo 1',
      kind: AssigneeKind.brigadist,
      onShift: true,
    ),
    const AvailablePerson(
      id: '00000000-0000-4000-8000-000000000203',
      displayName: 'Brigadista de ejemplo 2',
      kind: AssigneeKind.brigadist,
      onShift: false,
    ),
    const AvailablePerson(
      id: _neighborId,
      displayName: 'Vecina voluntaria de ejemplo',
      kind: AssigneeKind.neighbor,
      onShift: true,
    ),
  ];

  void _seed() {
    final at = now();
    DateTime ago(int minutes) => at.subtract(Duration(minutes: minutes));
    CaseHistoryEntry sent(int minutes) =>
        CaseHistoryEntry(from: null, to: CaseStatus.sent, at: ago(minutes), role: 'vecino');
    void add(_DemoCase item) => _cases[item.id] = item;

    add(
      _DemoCase(
        id: '00000000-0000-4000-8000-000000000001',
        priority: CasePriority.high,
        need: EmergencyNeed.water,
        status: CaseStatus.sent,
        cellLabel: 'Celda B2 (ejemplo)',
        createdAt: ago(12),
        unreviewedSince: ago(12),
        history: [sent(12)],
      ),
    );
    add(
      _DemoCase(
        id: '00000000-0000-4000-8000-000000000002',
        priority: CasePriority.high,
        need: EmergencyNeed.medicine,
        status: CaseStatus.sent,
        cellLabel: 'Celda C3 (ejemplo)',
        createdAt: ago(17),
        unreviewedSince: ago(17),
        history: [sent(17)],
      ),
    );
    add(
      _DemoCase(
        id: '00000000-0000-4000-8000-000000000003',
        priority: CasePriority.high,
        need: EmergencyNeed.food,
        status: CaseStatus.sent,
        cellLabel: 'Celda A1 (ejemplo)',
        createdAt: ago(3),
        unreviewedSince: ago(3),
        history: [sent(3)],
      ),
    );
    add(
      _DemoCase(
        id: '00000000-0000-4000-8000-000000000004',
        priority: CasePriority.medium,
        need: EmergencyNeed.transport,
        status: CaseStatus.sent,
        cellLabel: 'Celda B3 (ejemplo)',
        createdAt: ago(95),
        unreviewedSince: ago(95),
        history: [sent(95)],
      ),
    );
    add(
      _DemoCase(
        id: '00000000-0000-4000-8000-000000000005',
        priority: CasePriority.medium,
        need: EmergencyNeed.shelter,
        status: CaseStatus.seen,
        cellLabel: 'Celda A2 (ejemplo)',
        createdAt: ago(40),
        history: [
          sent(40),
          CaseHistoryEntry(
            from: CaseStatus.sent,
            to: CaseStatus.seen,
            at: ago(31),
            role: 'coordinador',
          ),
        ],
      ),
    );
    add(
      _DemoCase(
        id: '00000000-0000-4000-8000-000000000006',
        priority: CasePriority.low,
        need: EmergencyNeed.other,
        status: CaseStatus.sent,
        cellLabel: 'Celda C1 (ejemplo)',
        createdAt: ago(300),
        unreviewedSince: ago(300),
        history: [sent(300)],
      ),
    );
    final brigadist = _people.first;
    add(
      _DemoCase(
        id: '00000000-0000-4000-8000-000000000007',
        priority: CasePriority.high,
        need: EmergencyNeed.water,
        status: CaseStatus.onTheWay,
        cellLabel: 'Celda B1 (ejemplo)',
        createdAt: ago(50),
        assignee: CaseAssignee(
          id: brigadist.id,
          displayName: brigadist.displayName,
          kind: AssigneeKind.brigadist,
        ),
        // A fictitious point inside the pilot's demonstration rectangle.
        exactLocation: const ExactLocation(lat: -12.0841, lng: -77.0362),
        history: [
          sent(50),
          CaseHistoryEntry(
            from: CaseStatus.sent,
            to: CaseStatus.seen,
            at: ago(44),
            role: 'coordinador',
          ),
          CaseHistoryEntry(
            from: CaseStatus.seen,
            to: CaseStatus.onTheWay,
            at: ago(40),
            role: 'coordinador',
          ),
        ],
      ),
    );
  }

  Future<void> _latency() => Future<void>.delayed(const Duration(milliseconds: 250));

  bool _visible(_DemoCase item) => viewer.coordinates || item.assignee?.id == viewer.id;

  EmergencyCase _view(_DemoCase item) {
    final showsPoint = item.status == CaseStatus.onTheWay && item.assignee?.id == viewer.id;
    return EmergencyCase(
      id: item.id,
      version: item.version,
      priority: item.priority,
      need: item.need,
      status: item.status,
      cellLabel: item.cellLabel,
      createdAt: item.createdAt,
      unreviewedSince: item.unreviewedSince,
      assignee: item.assignee,
      history: List.unmodifiable(item.history),
      exactLocation: showsPoint ? item.exactLocation : null,
    );
  }

  @override
  Future<List<EmergencyCase>> queue(String zoneId) async {
    await _latency();
    return [
      for (final item in _cases.values)
        if (item.status.isOpen && _visible(item)) _view(item),
    ];
  }

  @override
  Future<EmergencyCase> detail(String caseId) async {
    await _latency();
    final item = _cases[caseId];
    if (item == null || !_visible(item)) throw demoProblem(404, 'recurso_no_encontrado');
    return _view(item);
  }

  @override
  Future<List<AvailablePerson>> availablePeople(String zoneId) async {
    await _latency();
    return _people;
  }

  @override
  Future<EmergencyCase> apply(
    String caseId, {
    required int seenVersion,
    required CaseCommand command,
    required String idempotencyKey,
  }) async {
    await _latency();
    final replay = _replies[idempotencyKey];
    if (replay != null) return replay;
    if (!viewer.coordinates) throw demoProblem(403, 'rol_requerido');
    final item = _cases[caseId];
    if (item == null) throw demoProblem(404, 'recurso_no_encontrado');
    if (item.version != seenVersion) throw demoProblem(409, 'conflicto_de_version');
    final action = command.action;
    if (!actionsFrom(item.status).contains(action)) throw demoProblem(409, 'transicion_invalida');
    final previous = item.status;
    String? reason;
    switch (command) {
      case MarkSeen():
        item.unreviewedSince = null;
      case AssignCase(:final personId, :final note):
        final person = _people.where((p) => p.id == personId).firstOrNull;
        if (person == null) throw demoProblem(422, 'no_procesable');
        item.assignee = CaseAssignee(
          id: person.id,
          displayName: person.displayName,
          kind: person.kind,
        );
        reason = note;
      case ReferCase(:final line, reason: final why):
        reason = '${line.number} · $why';
      case CloseUnattended(reason: final why):
        reason = why;
    }
    item.status = resultOf(action);
    item.version++;
    item.history.add(
      CaseHistoryEntry(
        from: previous,
        to: item.status,
        at: now(),
        role: viewer.has(OperationalRole.coordinator) ? 'coordinador' : 'administrador',
        reason: reason,
      ),
    );
    return _replies[idempotencyKey] = _view(item);
  }
}
