import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/auth_api.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/sign_in.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/celdas/domain/cells.dart';
import 'package:vecinal_consola/features/curaduria/domain/directory.dart';
import 'package:vecinal_consola/features/turnos/domain/shifts.dart';

final _now = DateTime.utc(2026, 11, 8, 12);

EmergencyCase _case(
  String id, {
  CasePriority priority = CasePriority.high,
  CaseStatus status = CaseStatus.sent,
  int age = 0,
  int? waiting,
  CaseAssignee? assignee,
  ExactLocation? location,
}) => EmergencyCase(
  id: id,
  version: 1,
  priority: priority,
  need: EmergencyNeed.water,
  status: status,
  cellLabel: 'Celda ficticia',
  createdAt: _now.subtract(Duration(minutes: age)),
  unreviewedSince: waiting == null ? null : _now.subtract(Duration(minutes: waiting)),
  assignee: assignee,
  exactLocation: location,
);

DirectoryEntry _entry({
  String id = 'test-entry',
  EntryType type = EntryType.number,
  String name = 'Entrada ficticia',
  String? phone = '116',
  EntryLocation? location,
  String source = 'Fuente ficticia',
  String? url,
  String day = '2026-11-08',
  String? address,
  String? description,
}) => DirectoryEntry(
  id: id,
  type: type,
  name: name,
  phone: phone,
  location: location,
  sourceName: source,
  sourceUrl: url,
  verifiedOn: day,
  address: address,
  description: description,
);

Map<String, Object?> _tokens() => {
  'tokenDeAcceso': 'fictitious-access',
  'refreshToken': 'fictitious-refresh',
  'expiraEn': '2026-11-08T13:00:00Z',
  'refreshExpiraEn': '2026-11-09T12:00:00Z',
  'usuario': <String, Object?>{
    'id': 'test-user',
    'nombreVisible': 'Cuenta ficticia',
    'zonaId': 'test-zone',
    'roles': ['coordinador', 'curador'],
  },
};

void main() {
  group('markFor', () {
    for (final row in [
      (const Duration(minutes: 89, seconds: 59), const Duration(hours: 2), ReviewMark.onTime),
      (const Duration(minutes: 90), const Duration(hours: 2), ReviewMark.aboutToEscalate),
      (const Duration(minutes: 5), const Duration(minutes: 10), ReviewMark.onTime),
      (
        const Duration(minutes: 5, seconds: 1),
        const Duration(minutes: 10),
        ReviewMark.aboutToEscalate,
      ),
      (const Duration(minutes: 15), const Duration(minutes: 15), ReviewMark.overdue),
      (const Duration(minutes: 16), const Duration(minutes: 15), ReviewMark.overdue),
      (const Duration(days: 30), null, ReviewMark.onTime),
    ]) {
      test('espera ${row.$1}, plazo ${row.$2}', () => expect(markFor(row.$1, row.$2), row.$3));
    }
    test('prioridad baja sin plazo y reloj futuro sin espera negativa', () {
      final clock = reviewClockOf(
        _case('low', priority: CasePriority.low, waiting: 999),
        _now,
        const ReviewPolicy(),
      )!;
      expect(clock.limit, isNull);
      expect(clock.mark, ReviewMark.onTime);
      expect(
        reviewClockOf(_case('future', waiting: -1), _now, const ReviewPolicy())!.waited,
        Duration.zero,
      );
      expect(reviewClockOf(_case('reviewed'), _now, const ReviewPolicy()), isNull);
    });
  });

  test('sortQueue prioriza, ordena espera y antigüedad sin mutar la entrada', () {
    final items = [
      _case('low', priority: CasePriority.low, waiting: 100),
      _case('reviewed-new', age: 2),
      _case('wait-new', waiting: 3),
      _case('medium', priority: CasePriority.medium, waiting: 90),
      _case('reviewed-old', age: 50),
      _case('wait-old', waiting: 20),
    ];
    final original = [...items];
    expect(sortQueue(items).map((item) => item.id), [
      'wait-old',
      'wait-new',
      'reviewed-old',
      'reviewed-new',
      'medium',
      'low',
    ]);
    expect(items, original);
    expect(sortQueue([]), isEmpty);
  });

  for (final status in CaseStatus.values) {
    test('actionsFrom ${status.name}', () {
      expect(actionsFrom(status), switch (status) {
        CaseStatus.sent => {CaseAction.markSeen},
        CaseStatus.seen => {CaseAction.assign, CaseAction.refer, CaseAction.closeUnattended},
        _ => <CaseAction>{},
      });
    });
  }

  test('showsExactLocation solo asignado, en camino y con punto disponible', () {
    const assignee = CaseAssignee(
      id: 'test-user',
      displayName: 'Persona ficticia',
      kind: AssigneeKind.brigadist,
    );
    for (final status in CaseStatus.values) {
      final item = _case(
        'test',
        status: status,
        assignee: assignee,
        location: const ExactLocation(lat: 0, lng: 0),
      );
      expect(showsExactLocation(item, 'test-user'), status == CaseStatus.onTheWay);
      expect(showsExactLocation(item, 'other-user'), isFalse);
    }
    expect(
      showsExactLocation(
        _case('test', status: CaseStatus.onTheWay, assignee: assignee),
        'test-user',
      ),
      isFalse,
    );
    expect(
      showsExactLocation(
        _case('test', status: CaseStatus.onTheWay, location: const ExactLocation(lat: 0, lng: 0)),
        'test-user',
      ),
      isFalse,
    );
  });

  for (final value in <int?>[null, -1, 0, 2, 3, 9, 10, 24, 25]) {
    test('CellCount $value aplica umbral y nivel', () {
      final count = CellCount(value);
      expect(count.value, value != null && value >= 3 ? value : null);
      expect(count.isBelowThreshold, value == null || value < 3);
      expect(
        levelOf(count),
        value == null || value < 3
            ? CellLevel.belowThreshold
            : value < 10
            ? CellLevel.low
            : value < 25
            ? CellLevel.medium
            : CellLevel.high,
      );
    });
  }

  test('coverageOf exige dos coordinadores activos y un turno vigente con bordes inclusivos', () {
    const operators = [
      ZoneOperator(id: 'one', displayName: 'Uno', role: OperationalRole.coordinator, active: true),
      ZoneOperator(id: 'two', displayName: 'Dos', role: OperationalRole.coordinator, active: true),
      ZoneOperator(
        id: 'disabled',
        displayName: 'Inactivo',
        role: OperationalRole.coordinator,
        active: false,
      ),
      ZoneOperator(id: 'other', displayName: 'Otro', role: OperationalRole.brigadist, active: true),
    ];
    Shift shift({DateTime? start, DateTime? end, DateTime? ended}) => Shift(
      id: 'shift',
      version: 1,
      personId: 'one',
      personName: 'Uno',
      role: OperationalRole.coordinator,
      startsAt: start ?? _now,
      endsAt: end ?? _now.add(const Duration(hours: 1)),
      endedAt: ended,
    );
    Coverage coverage(List<ZoneOperator> people, List<Shift> shifts) =>
        coverageOf(ShiftBoard(operators: people, shifts: shifts, updatedAt: _now), _now);
    expect(coverage(operators, [shift()]).covered, isTrue);
    expect(coverage(operators.skip(1).toList(), [shift()]).gaps, [CoverageGap.tooFewCoordinators]);
    expect(coverage(operators, []).gaps, [CoverageGap.noCurrentShift]);
    expect(coverage([], []).gaps, CoverageGap.values);
    for (final invalid in [
      shift(start: _now.add(const Duration(seconds: 1))),
      shift(start: _now.subtract(const Duration(hours: 1)), end: _now),
      shift(ended: _now),
    ]) {
      expect(coverage(operators, [invalid]).hasCurrentShift, isFalse);
    }
  });

  group('validateEntry', () {
    test('rechaza días inexistentes y coordenadas no finitas', () {
      for (final day in ['2026-02-30', '2026-00-10', '2026-04-31']) {
        expect(
          validateEntry(_entry(day: day), today: '2026-11-08').map((problem) => problem.kind),
          contains(EntryProblemKind.verifiedFormat),
        );
      }
      for (final value in [double.nan, double.infinity, double.negativeInfinity]) {
        expect(
          validateEntry(
            _entry(location: EntryLocation(lat: value, lng: 0)),
            today: '2026-11-08',
          ).map((problem) => problem.kind),
          contains(EntryProblemKind.latitudeRange),
        );
        expect(
          validateEntry(
            _entry(location: EntryLocation(lat: 0, lng: value)),
            today: '2026-11-08',
          ).map((problem) => problem.kind),
          contains(EntryProblemKind.longitudeRange),
        );
      }
    });
    test('acepta número y punto ficticio en los límites geográficos', () {
      for (final entry in [
        _entry(),
        _entry(
          type: EntryType.meetingPoint,
          phone: null,
          location: const EntryLocation(lat: -90, lng: 180),
          url: 'https://example.invalid/source',
        ),
      ]) {
        expect(validateEntry(entry, today: '2026-11-08'), isEmpty);
      }
    });
    final invalid = <EntryProblemKind, DirectoryEntry Function()>{
      EntryProblemKind.idFormat: () => _entry(id: '../bad'),
      EntryProblemKind.idRepeated: () => _entry(),
      EntryProblemKind.nameLength: () => _entry(name: 'x'),
      EntryProblemKind.phoneRequired: () => _entry(phone: null),
      EntryProblemKind.phoneFormat: () => _entry(phone: 'javascript:alert(1)'),
      EntryProblemKind.locationRequired: () => _entry(type: EntryType.shelter),
      EntryProblemKind.latitudeRange: () => _entry(location: const EntryLocation(lat: 91, lng: 0)),
      EntryProblemKind.longitudeRange: () =>
          _entry(location: const EntryLocation(lat: 0, lng: -181)),
      EntryProblemKind.addressLength: () => _entry(address: 'x' * 201),
      EntryProblemKind.descriptionLength: () => _entry(description: 'x' * 301),
      EntryProblemKind.sourceNameLength: () => _entry(source: ''),
      EntryProblemKind.sourceUrlHttps: () => _entry(url: 'javascript:alert(1)'),
      EntryProblemKind.verifiedFormat: () => _entry(day: 'not-a-day'),
      EntryProblemKind.verifiedFuture: () => _entry(day: '2026-11-09'),
    };
    for (final MapEntry(key: problem, value: entry) in invalid.entries) {
      test('rechaza ${problem.name}', () {
        expect(
          validateEntry(
            entry(),
            today: '2026-11-08',
            otherIds: problem == EntryProblemKind.idRepeated ? ['test-entry'] : [],
          ).map((item) => item.kind),
          contains(problem),
        );
      });
    }
  });

  test('suggestId normaliza tildes, signos, vacío y longitud máxima', () {
    expect(suggestId('  ÁRBOL, pingüino y NIÑO!  '), 'arbol-pinguino-y-nino');
    expect(suggestId('///'), isEmpty);
    expect(suggestId(''), isEmpty);
    expect(suggestId('a' * 61), 'a' * 60);
    expect(suggestId('${'a' * 59} b'), 'a' * 59);
  });

  test('normalizePhone solo conserva dígitos y no ejecuta contenido malicioso', () {
    expect(normalizePhone('900 000 000'), '+51900000000');
    expect(normalizePhone('+999 000 000 000'), '+999000000000');
    expect(normalizePhone('51900000000'), '+51900000000');
    expect(normalizePhone('800000000'), '+800000000');
    expect(normalizePhone('<script>alert(1)</script>'), '+1');
    expect(normalizePhone('javascript:alert()'), '+');
    expect(normalizePhone(''), '+');
    expect(normalizePhone('++999\r\nInjected: value'), '+999');
  });

  group('SessionTokens.fromJson', () {
    test('lee tokens, fechas y roles válidos; ignora roles desconocidos o maliciosos', () {
      final data = _tokens();
      (data['usuario']! as Map<String, Object?>)['roles'] = [
        'coordinador',
        'curador',
        '<script>',
        42,
        {'administrador': true},
      ];
      final tokens = SessionTokens.fromJson(data);
      expect(tokens.accessToken, 'fictitious-access');
      expect(tokens.refreshToken, 'fictitious-refresh');
      expect(tokens.expiresAt, DateTime.utc(2026, 11, 8, 13));
      expect(tokens.refreshExpiresAt, DateTime.utc(2026, 11, 9, 12));
      expect(tokens.user.roles, {OperationalRole.coordinator, OperationalRole.curator});
      expect(tokens.user.id, 'test-user');
    });
    for (final field in [
      'tokenDeAcceso',
      'refreshToken',
      'expiraEn',
      'refreshExpiraEn',
      'usuario',
    ]) {
      test('rechaza $field ausente o malicioso', () {
        for (final bad in [
          null,
          '',
          42,
          [],
          if (field != 'tokenDeAcceso' && field != 'refreshToken') '<script>',
        ]) {
          expect(
            () => SessionTokens.fromJson(_tokens()..[field] = bad),
            throwsA(isA<UnexpectedResponse>()),
          );
        }
      });
    }
    test('datos externos no pueden conceder roles por mapas ni cadenas', () {
      for (final roles in [
        'administrador',
        {'administrador': true},
        null,
      ]) {
        final data = _tokens();
        (data['usuario']! as Map<String, Object?>)['roles'] = roles;
        expect(SessionTokens.fromJson(data).user.isOperational, isFalse);
      }
      for (final bad in [null, [], '<script>']) {
        expect(() => SessionTokens.fromJson(bad), throwsA(isA<UnexpectedResponse>()));
      }
      final data = _tokens();
      (data['usuario']! as Map<String, Object?>)['id'] = 42;
      expect(() => SessionTokens.fromJson(data), throwsA(isA<UnexpectedResponse>()));
    });
  });
}
