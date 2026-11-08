import 'dart:async';

import 'package:dio/dio.dart';
import 'package:powersync/powersync.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/emergencias/data/help_request_queue.dart';
import 'package:vecinal/features/emergencias/data/own_help_request_repository.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';
import 'package:vecinal/features/emergencias/domain/public_emergency_board.dart';

/// Coverage of the zone as the API last confirmed it (Lot B, `GET /v1/zonas/{id}/cobertura`).
class ZoneCoverage {
  const ZoneCoverage({
    required this.eventId,
    required this.enabled,
    required this.mode,
    required this.checkedAt,
  });

  final String? eventId;
  final bool enabled;
  final String mode;
  final DateTime checkedAt;
}

/// The emergency dashboard of the account (Lot D) over Lots A and B.
///
/// - Requests go through A's encrypted queue with their id and key, and their state comes from the
///   author's stream: "sent" needs the server's receipt, never just the phone.
/// - Coverage and the event come from B and stay in the account's database, so a request can be
///   written without signal while the last confirmation is recent.
/// - Resources come from A's public stream of the zone; a report goes to B with type, quantity and
///   the approximate point, without free text.
/// - B has no route for offers: they stay on this phone and say so.
class OperationalEmergencyRepository implements EmergencyRepository {
  OperationalEmergencyRepository({
    required this.scope,
    required LocalSyncDatabase local,
    required this._requests,
    required this._board,
    required this._api,
    required this.fallbackLocation,
    DateTime Function()? clock,
    this.refreshEvery = const Duration(minutes: 5),
    this.coverageValidFor = const Duration(hours: 12),
  }) : _database = local.database,
       _clock = clock ?? DateTime.now;

  final EmergencyScope scope;

  /// Public reference point of the zone, for a request whose point already left the queue.
  final GeoPoint fallbackLocation;
  final PowerSyncDatabase _database;
  final OwnHelpRequestRepository _requests;
  final EmergencyBoardRepository? _board;
  final Dio _api;
  final DateTime Function() _clock;

  /// How often the coverage is asked again while something watches it (also on open and resume).
  final Duration refreshEvery;

  /// An older confirmation is no longer evidence of coverage.
  final Duration coverageValidFor;

  /// What the neighbor wrote, while this session lasts. Once sent, the queue drops the
  /// description and the point: the request then shows its summary.
  final _drafts = <String, HelpRequestDraft>{};
  final _offers = <HelpOffer>[];
  final _offerChanges = StreamController<void>.broadcast();

  @override
  Stream<EmergencySnapshot> watch() => Stream.multi((listener) {
    ZoneCoverage? coverage;
    var requests = const <OwnHelpRequest>[];
    var resources = const <CriticalResource>[];
    var coverageLoaded = false;
    var requestsLoaded = false;
    void emit() {
      if (!coverageLoaded || !requestsLoaded || listener.isClosed) return;
      final now = _clock();
      final verified =
          coverage != null &&
          coverage!.enabled &&
          coverage!.eventId != null &&
          now.difference(coverage!.checkedAt) < coverageValidFor;
      listener.add(
        EmergencySnapshot(
          coverageVerified: verified,
          activeEvent: coverage?.mode == 'emergencia',
          updatedAt: coverage?.checkedAt,
          requests: requests,
          offers: List.unmodifiable(_offers),
          resources: resources,
        ),
      );
    }

    final subscriptions = <StreamSubscription<Object?>>[
      _watchCoverage().listen((value) {
        coverage = value;
        coverageLoaded = true;
        emit();
      }, onError: listener.addError),
      _watchRequests().listen((value) {
        requests = value;
        requestsLoaded = true;
        emit();
      }, onError: listener.addError),
      _offerChanges.stream.listen((_) => emit()),
      if (_board case final board?)
        board.watch().listen((snapshot) {
          resources = List.unmodifiable(snapshot.resources.map(_resource).nonNulls);
          emit();
        }, onError: listener.addError),
    ];
    unawaited(refreshCoverage());
    final timer = Timer.periodic(refreshEvery, (_) => unawaited(refreshCoverage()));
    listener.onCancel = () async {
      timer.cancel();
      await Future.wait(subscriptions.map((subscription) => subscription.cancel()));
    };
  });

  /// Asks B again. Without signal the last confirmation stays, with its date.
  Future<void> refreshCoverage() async {
    try {
      final response = await _api.get<Object?>('/v1/zonas/${scope.zoneId}/cobertura');
      final body = response.data;
      if (response.statusCode != 200 || body is! Map) return;
      await _database.writeTransaction((tx) async {
        await tx.execute('DELETE FROM cobertura_zona WHERE id = ?', [scope.zoneId]);
        await tx.execute(
          '''
          INSERT INTO cobertura_zona (id, evento_id, habilitada, modo, revisada_en)
          VALUES (?, ?, ?, ?, ?)
          ''',
          [
            scope.zoneId,
            body['eventoId'] as String?,
            body['habilitada'] == true ? 1 : 0,
            body['modo'] as String? ?? 'normal',
            _clock().toUtc().toIso8601String(),
          ],
        );
      });
    } on DioException {
      // No signal or no answer: the dashboard keeps the last confirmation and its date.
    }
  }

  Stream<ZoneCoverage?> _watchCoverage() => _database
      .watch(
        'SELECT * FROM cobertura_zona WHERE id = ?',
        parameters: [scope.zoneId],
        triggerOnTables: ['cobertura_zona'],
      )
      .map((rows) {
        final row = rows.firstOrNull;
        final checkedAt = DateTime.tryParse(row?['revisada_en'] as String? ?? '');
        if (row == null || checkedAt == null) return null;
        return ZoneCoverage(
          eventId: row['evento_id'] as String?,
          enabled: row['habilitada'] == 1,
          mode: row['modo'] as String? ?? 'normal',
          checkedAt: checkedAt,
        );
      });

  Stream<List<OwnHelpRequest>> _watchRequests() => _database
      .watch(
        'SELECT recurso_id FROM envios WHERE tipo = ? ORDER BY creado_en DESC, id DESC',
        parameters: [SubmissionKind.helpRequest.name],
        triggerOnTables: [
          'envios',
          'mis_pedidos_ayuda',
          'historial_mis_pedidos',
          'pedidos_propios_cerrados',
        ],
      )
      .asyncMap((rows) async {
        final result = <OwnHelpRequest>[];
        for (final row in rows) {
          final request = await _request(row['recurso_id'] as String);
          if (request != null) result.add(request);
        }
        return List<OwnHelpRequest>.unmodifiable(result);
      });

  Future<OwnHelpRequest?> _request(String id) async {
    final state = await _requests.watch(id).first;
    if (state == null) return null;
    final synced = await _database.getOptional(
      'SELECT necesidad, creado_en FROM mis_pedidos_ayuda WHERE id = ?',
      [id],
    );
    final sent = await _database.getOptional(
      'SELECT creado_en, clave_idempotencia FROM envios WHERE recurso_id = ?',
      [id],
    );
    final draft = _drafts[id];
    final createdAt =
        DateTime.tryParse(sent?['creado_en'] as String? ?? '') ??
        DateTime.tryParse(synced?['creado_en'] as String? ?? '') ??
        _clock();
    final rejection = state.rejectionReason;
    final history = <RequestHistoryEntry>[
      RequestHistoryEntry(status: HelpRequestStatus.local, at: createdAt),
      if (state.received && state.history.isEmpty && state.sentAt != null)
        RequestHistoryEntry(status: HelpRequestStatus.sent, at: state.sentAt!),
      for (final entry in state.history)
        RequestHistoryEntry(
          status: _status(entry.stage),
          at: entry.occurredAt,
          reason: entry.reason,
        ),
    ];
    final latest = state.latest;
    return OwnHelpRequest(
      id: id,
      idempotencyKey: sent?['clave_idempotencia'] as String? ?? draft?.idempotencyKey ?? id,
      need: draft?.need ?? _needFromApi(synced?['necesidad'] as String?),
      description: draft?.description ?? '',
      locationLabel: draft?.locationLabel ?? '',
      approximateLocation: draft?.approximateLocation ?? fallbackLocation,
      createdAt: createdAt,
      history: history,
      sentAt: state.sentAt,
      reason: rejection == null ? latest?.reason : _rejection(rejection.code),
      nextStep: latest?.nextStep,
      canConfirmAttendance: latest?.stage == HelpRequestStage.onTheWay,
    );
  }

  @override
  Future<OwnHelpRequest> saveRequest(HelpRequestDraft draft) async {
    final row = await _database.getOptional('SELECT * FROM cobertura_zona WHERE id = ?', [
      scope.zoneId,
    ]);
    final eventId = row?['evento_id'] as String?;
    final checkedAt = DateTime.tryParse(row?['revisada_en'] as String? ?? '');
    if (row?['habilitada'] != 1 ||
        eventId == null ||
        checkedAt == null ||
        _clock().difference(checkedAt) >= coverageValidFor) {
      throw StateError('La zona no tiene coordinación confirmada.');
    }
    final reference = draft.locationLabel.trim();
    final description = draft.description.trim();
    await _requests.queue.save(
      requestId: draft.id,
      idempotencyKey: draft.idempotencyKey,
      body: HelpRequestPayload(
        eventId: eventId,
        need: _need(draft.need),
        // The written reference helps the brigade member: it travels only in the private detail.
        description: [
          if (description.isNotEmpty) description else 'Necesito ayuda',
          if (reference.isNotEmpty) 'Referencia: $reference',
        ].join('\n'),
        latitude: draft.approximateLocation.lat,
        longitude: draft.approximateLocation.lng,
      ),
    );
    _drafts[draft.id.toLowerCase()] = draft;
    return (await _request(draft.id.toLowerCase())) ??
        (throw StateError('El pedido no quedó en la cola.'));
  }

  @override
  Future<void> confirmAttendance(String requestId) async {
    final row = await _database.getOptional(
      'SELECT estado, version FROM mis_pedidos_ayuda WHERE id = ?',
      [requestId.toLowerCase()],
    );
    if (row == null || row['estado'] != HelpRequestStage.onTheWay.apiValue) {
      throw StateError('Solo se confirma un pedido en camino.');
    }
    // Online: B checks that only the author confirms and that the version is the one seen.
    await _api.post<Object?>(
      '/v1/pedidos-ayuda/${requestId.toLowerCase()}/estado',
      data: {'versionVista': row['version'], 'estado': HelpRequestStage.attended.apiValue},
      options: Options(headers: {idempotencyKeyHeader: newLocalId()}),
    );
  }

  @override
  Future<void> saveOffer(HelpOffer offer) async {
    if (_offers.any((o) => o.id == offer.id || o.idempotencyKey == offer.idempotencyKey)) return;
    _offers.insert(
      0,
      HelpOffer(
        id: offer.id,
        idempotencyKey: offer.idempotencyKey,
        description: offer.description,
        createdAt: offer.createdAt,
      ),
    );
    _offerChanges.add(null);
  }

  @override
  Future<void> reportResource(ResourceReportDraft draft) async {
    final type = _resourceType(draft.kind);
    final quantity = draft.quantity;
    final location = draft.location;
    if (type == null || quantity == null || location == null) {
      throw StateError('El reporte necesita tipo, cantidad y punto aproximado.');
    }
    await _api.post<Object?>(
      '/v1/zonas/${scope.zoneId}/recursos',
      data: {
        'id': draft.id,
        'tipo': type,
        'cantidad': quantity,
        'ubicacion': {'lat': location.lat, 'lng': location.lng},
      },
      options: Options(headers: {idempotencyKeyHeader: draft.idempotencyKey}),
    );
  }

  static CriticalResource? _resource(PublicCriticalResource resource) {
    final kind = switch (resource.kind) {
      'agua' => ResourceKind.water,
      'alimentos' => ResourceKind.food,
      'medicamentos' => ResourceKind.medicine,
      'albergue' => ResourceKind.shelter,
      'punto_encuentro' => ResourceKind.meetingPoint,
      _ => ResourceKind.other,
    };
    final verification = switch (resource.verification) {
      'verificado' => ResourceVerification.verified,
      'confirmado' => ResourceVerification.neighbors,
      _ => ResourceVerification.unverified,
    };
    final source = resource.source;
    final verifiedAt = resource.verifiedAt;
    return CriticalResource(
      id: resource.id,
      kind: kind,
      description: resource.label ?? 'Cantidad reportada: ${resource.quantity}',
      reportedAt: resource.reportedAt,
      verification: verification,
      confirmations: resource.confirmations,
      // Only B's human verification makes a source; a neighbor's report never does.
      source: verification == ResourceVerification.verified && verifiedAt != null
          ? ResourceSource(
              name: resource.label ?? (source?.host ?? 'Fuente verificada'),
              verifiedAt: verifiedAt,
              url: source,
              official: resource.official,
            )
          : null,
    );
  }

  static HelpRequestStatus _status(HelpRequestStage stage) => switch (stage) {
    HelpRequestStage.sent => HelpRequestStatus.sent,
    HelpRequestStage.seen => HelpRequestStatus.seen,
    HelpRequestStage.onTheWay => HelpRequestStatus.onTheWay,
    HelpRequestStage.attended => HelpRequestStatus.attended,
    HelpRequestStage.referred => HelpRequestStatus.referred,
    HelpRequestStage.closedWithoutAssistance => HelpRequestStatus.closedUnattended,
  };

  static HelpRequestNeed _need(EmergencyNeed need) => switch (need) {
    EmergencyNeed.water => HelpRequestNeed.water,
    EmergencyNeed.food => HelpRequestNeed.food,
    EmergencyNeed.medicine => HelpRequestNeed.medicine,
    EmergencyNeed.transport => HelpRequestNeed.transport,
    EmergencyNeed.shelter => HelpRequestNeed.shelter,
    EmergencyNeed.other => HelpRequestNeed.other,
  };

  static EmergencyNeed _needFromApi(String? value) => switch (value) {
    'agua' => EmergencyNeed.water,
    'alimentos' => EmergencyNeed.food,
    'medicamentos' => EmergencyNeed.medicine,
    'traslado' => EmergencyNeed.transport,
    'albergue' => EmergencyNeed.shelter,
    _ => EmergencyNeed.other,
  };

  static String? _resourceType(ResourceKind kind) => switch (kind) {
    ResourceKind.water => 'agua',
    ResourceKind.food => 'alimentos',
    ResourceKind.medicine => 'medicamentos',
    ResourceKind.shelter => 'albergue',
    ResourceKind.meetingPoint => 'punto_encuentro',
    ResourceKind.other => null,
  };

  /// Rejections the connector keeps (it drops any free text the server returned).
  static String _rejection(String code) => switch (code) {
    'zona_sin_cobertura' =>
      'La zona no tenía coordinación disponible. Usa el directorio de emergencia.',
    'riesgo_vital' => 'Si hay riesgo para la vida, llama al 116, 105 o 106.',
    'ubicacion_fuera_de_zona' => 'La ubicación quedó fuera de tu zona.',
    'evento_no_activo' => 'La emergencia de la zona ya terminó.',
    _ => 'No se pudo completar el envío. Usa las alternativas oficiales.',
  };
}
