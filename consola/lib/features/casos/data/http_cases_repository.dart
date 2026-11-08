import 'package:uuid/uuid.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/features/casos/domain/cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';

/// Cases over the Emergencias API of Phase 2, Lot B (`contracts/emergencias.openapi.json`).
///
/// The queue never carries the description nor the coordinates; the detail is audited by the API
/// and only opens for the people assigned to the case. B lets only an assigned coordinator change
/// a case: when another coordinator of the zone acts on it, the repository first takes it for
/// them (`rol: coordinador`), as the contract describes.
class HttpCasesRepository implements CasesRepository {
  HttpCasesRepository(this._api, this._viewer);

  final ConsoleApi _api;
  final Operator _viewer;

  /// Last queue rows by case id: assignments and names for the detail and the changes.
  final _known = <String, EmergencyCase>{};
  final _coordinators = <String, Set<String>>{};
  final _names = <String, String>{};

  static const _pageSize = 100;
  static const _maxPages = 10;

  @override
  Future<List<EmergencyCase>> queue(String zoneId) async {
    await _loadNames(zoneId);
    final cases = <EmergencyCase>[];
    String? cursor;
    for (var page = 0; page < _maxPages; page++) {
      final json = await _api.getJson(
        '/v1/operacion/zonas/$zoneId/casos',
        query: {'limite': _pageSize, 'cursor': ?cursor},
      );
      for (final row in objects(json, 'elementos')) {
        cases.add(_remember(row));
      }
      cursor = json['siguienteCursor'] as String?;
      if (cursor == null) break;
    }
    return cases;
  }

  @override
  Future<EmergencyCase> detail(String caseId) async {
    try {
      final json = await _api.getJson('/v1/pedidos-ayuda/$caseId');
      final history = [for (final row in objects(json, 'historial')) _historyEntry(row)];
      final exact = json['ubicacionExacta'];
      return _remember(
        json,
        history: history,
        exactLocation: exact is Map
            ? ExactLocation(
                lat: (exact['lat'] as num).toDouble(),
                lng: (exact['lng'] as num).toDouble(),
              )
            : null,
      );
    } on ApiProblem catch (problem) {
      // A coordinator not assigned yet only sees what the queue already showed.
      final known = _known[caseId];
      if (problem.problem.status == 404 && known != null) return known;
      rethrow;
    }
  }

  @override
  Future<List<AvailablePerson>> availablePeople(String zoneId) async {
    final json = await _api.getJson('/v1/operacion/zonas/$zoneId/personas');
    return [
      for (final row in objects(json, 'elementos'))
        if (row['rol'] == 'brigadista')
          AvailablePerson(
            id: field<String>(row, 'id'),
            displayName: field<String>(row, 'nombre'),
            kind: AssigneeKind.brigadist,
            onShift: row['activo'] != false,
          ),
    ];
  }

  @override
  Future<EmergencyCase> apply(
    String caseId, {
    required int seenVersion,
    required CaseCommand command,
    required String idempotencyKey,
  }) async {
    var version = seenVersion;
    if (!(_coordinators[caseId]?.contains(_viewer.id) ?? false)) {
      final taken = await _api.postJson(
        '/v1/pedidos-ayuda/$caseId/asignaciones',
        body: {'versionVista': version, 'usuarioId': _viewer.id, 'rol': 'coordinador'},
        // Derived from the attempt's key: retrying the same attempt takes the case only once.
        idempotencyKey: const Uuid().v5(Namespace.url.value, '$idempotencyKey:tomar'),
      );
      version = field<int>(taken, 'version');
    }
    final json = switch (command) {
      MarkSeen() => await _changeState(caseId, version, 'visto', null, idempotencyKey),
      AssignCase(:final personId) => await _api.postJson(
        '/v1/pedidos-ayuda/$caseId/asignaciones',
        body: {'versionVista': version, 'usuarioId': personId, 'rol': 'brigadista'},
        idempotencyKey: idempotencyKey,
      ),
      ReferCase(:final line, :final reason) => await _changeState(
        caseId,
        version,
        'derivado',
        'Línea ${line.number}: $reason',
        idempotencyKey,
      ),
      CloseUnattended(:final reason) => await _changeState(
        caseId,
        version,
        'cerrado_sin_atender',
        reason,
        idempotencyKey,
      ),
    };
    final updated = _caseFrom(json);
    // An open case is read again with its history; a closed one leaves the assigned view.
    return updated.status.isOpen ? detail(caseId) : updated;
  }

  Future<Map<String, Object?>> _changeState(
    String caseId,
    int version,
    String state,
    String? reason,
    String idempotencyKey,
  ) => _api.postJson(
    '/v1/pedidos-ayuda/$caseId/estado',
    body: {'versionVista': version, 'estado': state, 'motivo': ?reason},
    idempotencyKey: idempotencyKey,
  );

  Future<void> _loadNames(String zoneId) async {
    try {
      final json = await _api.getJson('/v1/operacion/zonas/$zoneId/personas');
      for (final row in objects(json, 'elementos')) {
        _names[field<String>(row, 'id')] = field<String>(row, 'nombre');
      }
    } on ApiProblem {
      // Names are a convenience: the queue still opens without them.
    }
  }

  EmergencyCase _remember(
    Map<String, Object?> json, {
    List<CaseHistoryEntry>? history,
    ExactLocation? exactLocation,
  }) {
    final item = _caseFrom(json, history: history, exactLocation: exactLocation);
    final assignments = json['asignaciones'];
    if (assignments is List) {
      _coordinators[item.id] = {
        for (final row in assignments.whereType<Map<Object?, Object?>>())
          if (row['rol'] == 'coordinador') '${row['usuarioId']}',
      };
    }
    _known[item.id] = item;
    return item;
  }

  EmergencyCase _caseFrom(
    Map<String, Object?> json, {
    List<CaseHistoryEntry>? history,
    ExactLocation? exactLocation,
  }) {
    final status = caseStatusFromApi(field<String>(json, 'estado'));
    final createdAt = instant(json, 'creadoEn');
    final id = field<String>(json, 'id');
    CaseAssignee? assignee;
    final assignments = json['asignaciones'];
    if (assignments is List) {
      for (final row in assignments.whereType<Map<Object?, Object?>>()) {
        if (row['rol'] != 'brigadista') continue;
        final personId = '${row['usuarioId']}';
        assignee = CaseAssignee(
          id: personId,
          displayName: _names[personId] ?? 'Brigadista asignado',
          kind: AssigneeKind.brigadist,
        );
      }
    } else {
      assignee = _known[id]?.assignee;
    }
    return EmergencyCase(
      id: id,
      version: field<int>(json, 'version'),
      priority: casePriorityFromApi(field<String>(json, 'prioridad')),
      need: caseNeedFromApi(field<String>(json, 'necesidad')),
      status: status,
      cellLabel: 'Celda ${json['celda'] ?? 'sin publicar'}',
      createdAt: createdAt,
      // Waiting for the first human review until a coordinator marks it seen.
      unreviewedSince: status == CaseStatus.sent ? createdAt : null,
      assignee: assignee,
      history: history ?? _known[id]?.history ?? const [],
      exactLocation: exactLocation,
    );
  }

  static CaseHistoryEntry _historyEntry(Map<String, Object?> row) {
    final from = row['desde'];
    return CaseHistoryEntry(
      from: from is String ? caseStatusFromApi(from) : null,
      to: caseStatusFromApi(field<String>(row, 'hasta')),
      at: instant(row, 'ocurridoEn'),
      role: field<String>(row, 'rol'),
      reason: row['motivo'] as String?,
    );
  }
}

CaseStatus caseStatusFromApi(String value) => switch (value) {
  'enviado' => CaseStatus.sent,
  'visto' => CaseStatus.seen,
  'en_camino' => CaseStatus.onTheWay,
  'atendido' => CaseStatus.attended,
  'derivado' => CaseStatus.referred,
  'cerrado_sin_atender' => CaseStatus.closedUnattended,
  _ => throw UnexpectedResponse('Estado desconocido: $value'),
};

CasePriority casePriorityFromApi(String value) => switch (value) {
  'alta' => CasePriority.high,
  'media' => CasePriority.medium,
  'baja' => CasePriority.low,
  _ => throw UnexpectedResponse('Prioridad desconocida: $value'),
};

EmergencyNeed caseNeedFromApi(String value) => switch (value) {
  'agua' => EmergencyNeed.water,
  'alimentos' => EmergencyNeed.food,
  'medicamentos' => EmergencyNeed.medicine,
  'traslado' => EmergencyNeed.transport,
  'albergue' => EmergencyNeed.shelter,
  _ => EmergencyNeed.other,
};
