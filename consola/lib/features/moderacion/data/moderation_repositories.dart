import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/features/moderacion/domain/moderation.dart';

final moderationRepositoryProvider = Provider<ModerationRepository?>((ref) {
  if (ref.watch(currentOperatorProvider) == null) return null;
  if (ref.watch(demoDataProvider)) return DemoModerationRepository(now: ref.watch(clockProvider));
  return HttpModerationRepository(ref.watch(consoleApiProvider));
});

/// Phase 1 contract (`PaginaDeCasos`, `CasoDeModeracion`, `DecisionDeModeracion`).
class HttpModerationRepository implements ModerationRepository {
  HttpModerationRepository(this._api);

  final ConsoleApi _api;

  static const _pageSize = 20;

  @override
  Future<ModerationPage> list({required ModerationState state, String? cursor}) async {
    final body = await _api.getJson(
      '/v1/moderacion/casos',
      query: {'estado': state.code, 'limite': _pageSize, 'cursor': ?cursor},
    );
    final next = body['siguienteCursor'];
    return ModerationPage(
      cases: [for (final row in objects(body, 'datos')) _case(row)],
      nextCursor: next is String && next.isNotEmpty ? next : null,
    );
  }

  @override
  Future<ModerationCase> decide(
    String caseId, {
    required ModerationAction action,
    required String reason,
    required String idempotencyKey,
  }) async {
    final body = await _api.postJson(
      '/v1/moderacion/casos/$caseId/decision',
      body: {'accion': action.code, 'motivo': reason},
      idempotencyKey: idempotencyKey,
      expected: const {200},
    );
    return _case(body);
  }

  static ModerationCase _case(Map<String, Object?> row) => ModerationCase(
    id: field<String>(row, 'id'),
    contentType: field<String>(row, 'tipoContenido'),
    contentId: field<String>(row, 'contenidoId'),
    state: field<String>(row, 'estado') == ModerationState.resolved.code
        ? ModerationState.resolved
        : ModerationState.pending,
    reasonCode: field<String>(row, 'motivo'),
    lastAction: ModerationAction.fromCode(row['ultimaAccion'] as String?),
    createdAt: instant(row, 'creadoEn'),
    updatedAt: instant(row, 'actualizadoEn'),
    firstReviewAt: optionalInstant(row, 'primeraRevisionEn'),
  );
}

/// Fictitious cases for `CONSOLE_DATA=demo`.
class DemoModerationRepository implements ModerationRepository {
  DemoModerationRepository({required this.now}) {
    final at = now();
    const kinds = [
      ('publicacion', 'spam'),
      ('resena', 'ofensivo'),
      ('foto', 'datos_personales'),
      ('servicio', 'informacion_falsa'),
      ('resena', 'patron_de_resenas'),
    ];
    for (var index = 0; index < kinds.length; index++) {
      final (type, reason) = kinds[index];
      final created = at.subtract(Duration(minutes: 20 + index * 35));
      _cases.add(
        ModerationCase(
          id: '00000000-0000-4000-8000-00000000040$index',
          contentType: type,
          contentId: '00000000-0000-4000-8000-00000000041$index',
          state: ModerationState.pending,
          reasonCode: reason,
          lastAction: null,
          createdAt: created,
          updatedAt: created,
          firstReviewAt: null,
        ),
      );
    }
  }

  final DateTime Function() now;
  final _cases = <ModerationCase>[];
  final _replies = <String, ModerationCase>{};

  @override
  Future<ModerationPage> list({required ModerationState state, String? cursor}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return ModerationPage(
      cases: [
        for (final item in _cases)
          if (item.state == state) item,
      ],
      nextCursor: null,
    );
  }

  @override
  Future<ModerationCase> decide(
    String caseId, {
    required ModerationAction action,
    required String reason,
    required String idempotencyKey,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final replay = _replies[idempotencyKey];
    if (replay != null) return replay;
    final index = _cases.indexWhere((item) => item.id == caseId);
    if (index < 0) throw demoProblem(404, 'recurso_no_encontrado');
    final current = _cases[index];
    if (current.state == ModerationState.resolved) throw demoProblem(409, 'conflicto');
    final at = now();
    final resolved = ModerationCase(
      id: current.id,
      contentType: current.contentType,
      contentId: current.contentId,
      state: ModerationState.resolved,
      reasonCode: current.reasonCode,
      lastAction: action,
      createdAt: current.createdAt,
      updatedAt: at,
      firstReviewAt: current.firstReviewAt ?? at,
    );
    _cases[index] = resolved;
    return _replies[idempotencyKey] = resolved;
  }
}
