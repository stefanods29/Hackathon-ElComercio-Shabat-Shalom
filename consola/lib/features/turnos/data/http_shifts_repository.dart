import 'package:uuid/uuid.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/features/turnos/domain/shifts.dart';

/// Shifts of Phase 2, Lot B (`/v1/operacion/zonas/{zonaId}/turnos`). The API applies the rules:
/// shifts of up to 24 hours without overlaps, and 409 `zona_sin_cobertura` when it matters.
class HttpShiftsRepository implements ShiftsRepository {
  HttpShiftsRepository(this._api);

  final ConsoleApi _api;

  /// Role of each operator in the last board: a shift is planned for that role.
  final _roles = <String, OperationalRole>{};
  final _names = <String, String>{};

  @override
  Future<ShiftBoard> board(String zoneId) async {
    final json = await _api.getJson('/v1/operacion/zonas/$zoneId/turnos');
    final operators = <ZoneOperator>[];
    for (final row in objects(json, 'operadores')) {
      final role = OperationalRole.fromCode(field<String>(row, 'rol'));
      if (role == null) continue;
      final person = ZoneOperator(
        id: field<String>(row, 'id'),
        displayName: field<String>(row, 'nombre'),
        role: role,
        active: row['activo'] != false,
      );
      _roles[person.id] = role;
      _names[person.id] = person.displayName;
      operators.add(person);
    }
    return ShiftBoard(
      operators: operators,
      shifts: [for (final row in objects(json, 'turnos')) ?_shift(row)],
      updatedAt: instant(json, 'actualizadoEn'),
    );
  }

  @override
  Future<Shift> create(String zoneId, ShiftDraft draft, {required String idempotencyKey}) async {
    if (!_roles.containsKey(draft.personId)) await board(zoneId);
    final role = _roles[draft.personId];
    if (role == null) throw const UnexpectedResponse('La persona no figura en el tablero.');
    final json = await _api.postJson(
      '/v1/operacion/zonas/$zoneId/turnos',
      body: {
        // The id is fixed per attempt, like the key: a retry never plans the shift twice.
        'id': const Uuid().v5(Namespace.url.value, '$idempotencyKey:turno'),
        'usuarioId': draft.personId,
        'rol': role.code,
        'inicio': draft.startsAt.toUtc().toIso8601String(),
        'fin': draft.endsAt.toUtc().toIso8601String(),
      },
      idempotencyKey: idempotencyKey,
    );
    return _shift(json) ?? (throw const UnexpectedResponse('Turno inválido.'));
  }

  @override
  Future<Shift> end(Shift shift, {required String idempotencyKey}) async {
    final json = await _api.postJson(
      '/v1/operacion/turnos/${shift.id}/finalizar',
      body: {'versionVista': shift.version},
      idempotencyKey: idempotencyKey,
    );
    return _shift(json) ?? (throw const UnexpectedResponse('Turno inválido.'));
  }

  Shift? _shift(Map<String, Object?> row) {
    final role = OperationalRole.fromCode(field<String>(row, 'rol'));
    if (role == null) return null;
    final personId = field<String>(row, 'usuarioId');
    return Shift(
      id: field<String>(row, 'id'),
      version: field<int>(row, 'version'),
      personId: personId,
      personName: _names[personId] ?? role.code,
      role: role,
      startsAt: instant(row, 'inicio'),
      endsAt: instant(row, 'fin'),
      endedAt: optionalInstant(row, 'finalizadoEn'),
    );
  }
}
