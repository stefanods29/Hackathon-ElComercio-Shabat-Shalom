import 'dart:async';

import 'package:powersync/powersync.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/submission_row.dart';
import 'package:vecinal/features/emergencias/data/help_request_queue.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';

/// The request side of the emergency board's repository, bound to one encrypted account.
class OwnHelpRequestRepository {
  OwnHelpRequestRepository(
    LocalSyncDatabase local, {
    DateTime Function()? clock,
    Future<void Function()> Function(String id)? subscribe,
  }) : _database = local.database,
       _subscribe = subscribe ?? ((id) => _openStream(local.database, id)),
       queue = HelpRequestQueue(local, clock: clock);

  final PowerSyncDatabase _database;
  final Future<void Function()> Function(String id) _subscribe;
  final HelpRequestQueue queue;
  StreamSubscription<List<String>>? _ids;
  final _openRequests = <String, StreamSubscription<OwnHelpRequestState?>>{};

  /// Keep open requests current while the account is active, even outside the emergency screen.
  void start({required void Function(Object, StackTrace) onError}) {
    _ids ??= watchIds().listen((ids) {
      for (final id in ids) {
        _openRequests.putIfAbsent(
          id,
          () => _watch(id, subscribe: true).listen(
            (_) {},
            onError: (Object error, StackTrace stack) {
              _openRequests.remove(id);
              onError(error, stack);
            },
          ),
        );
      }
    }, onError: onError);
  }

  Future<void> close() async {
    await _ids?.cancel();
    _ids = null;
    final requests = _openRequests.values.toList();
    _openRequests.clear();
    await Future.wait(requests.map((request) => request.cancel()));
  }

  static Future<void Function()> _openStream(PowerSyncDatabase database, String id) async {
    final stream = database.syncStream('mi_pedido', {'pedido_id': id});
    final subscription = await stream.subscribe(ttl: Duration.zero);
    return subscription.unsubscribe;
  }

  Stream<List<String>> watchIds() => _database
      .watch(
        'SELECT recurso_id FROM envios WHERE tipo = ? ORDER BY creado_en DESC, id DESC',
        parameters: [SubmissionKind.helpRequest.name],
        triggerOnTables: ['envios'],
      )
      .map((rows) => rows.map((row) => row['recurso_id'] as String).toList(growable: false));

  Stream<OwnHelpRequestState?> watch(String requestId) => _watch(requestId, subscribe: false);

  Stream<OwnHelpRequestState?> _watch(String requestId, {required bool subscribe}) async* {
    final id = requestId.toLowerCase();
    void Function()? unsubscribe;
    try {
      await for (final _ in _database.watch(
        'SELECT id FROM envios WHERE recurso_id = ?',
        parameters: [id],
        triggerOnTables: [
          'envios',
          'mis_pedidos_ayuda',
          'historial_mis_pedidos',
          'pedidos_propios_cerrados',
        ],
      )) {
        final snapshot = await _read(id);
        final state = snapshot.state;
        final closed = snapshot.closed;
        if (closed != null) await _archive(closed);
        if (closed != null || snapshot.archived || state?.rejectionReason != null) {
          unsubscribe?.call();
          unsubscribe = null;
          yield state;
          return;
        }
        yield state;
        if (subscribe && state != null) unsubscribe ??= await _subscribe(id);
      }
    } finally {
      unsubscribe?.call();
    }
  }

  Future<void> _archive(HelpRequestHistoryEntry entry) => _database.writeTransaction((tx) async {
    final newer = await tx.getOptional(
      'SELECT id FROM pedidos_propios_cerrados WHERE id = ? AND version >= ?',
      [entry.requestId, entry.version],
    );
    if (newer != null) return;
    await tx.execute(
      '''
      INSERT OR REPLACE INTO pedidos_propios_cerrados (id, estado, version, cerrado_en, motivo)
      VALUES (?, ?, ?, ?, ?)
      ''',
      [
        entry.requestId,
        entry.stage.apiValue,
        entry.version,
        entry.occurredAt.toIso8601String(),
        entry.reason,
      ],
    );
  });

  Future<({OwnHelpRequestState? state, HelpRequestHistoryEntry? closed, bool archived})> _read(
    String id,
  ) => _database.readTransaction((tx) async {
    final submissionRow = await tx.getOptional(
      'SELECT * FROM envios WHERE tipo = ? AND recurso_id = ?',
      [SubmissionKind.helpRequest.name, id],
    );
    final submission = submissionRow == null ? null : submissionFromRow(submissionRow);
    final cached = await tx.getOptional('SELECT * FROM pedidos_propios_cerrados WHERE id = ?', [
      id,
    ]);
    final synced = await tx.getOptional('SELECT * FROM mis_pedidos_ayuda WHERE id = ?', [id]);
    final useCache =
        cached != null &&
        (synced == null || (cached['version'] as int) >= (synced['version'] as int));
    final current = useCache ? cached : synced;
    if (current == null && submission == null) {
      return (state: null, closed: null, archived: false);
    }

    final history = <HelpRequestHistoryEntry>[];
    final currentStage = HelpRequestStage.fromApi(current?['estado']);
    final version = current?['version'] as int?;
    final closedAt = DateTime.tryParse(current?['cerrado_en'] as String? ?? '');
    HelpRequestHistoryEntry? closed;
    if (currentStage != null && version != null) {
      final rows = useCache
          ? const <Map<String, Object?>>[]
          : await tx.getAll(
              '''
              SELECT hasta, ocurrido_en, motivo
              FROM historial_mis_pedidos WHERE pedido_id = ?
              ORDER BY ocurrido_en, CAST(id AS INTEGER)
              ''',
              [id],
            );
      for (final row in rows) {
        final stage = HelpRequestStage.fromApi(row['hasta']);
        final at = DateTime.tryParse(row['ocurrido_en'] as String? ?? '');
        if (stage == null || at == null) continue;
        history.add(
          HelpRequestHistoryEntry(
            requestId: id,
            // Assignment changes can increment the request version without adding a state row.
            version: version - rows.length + history.length,
            stage: stage,
            occurredAt: at,
            reason: row['motivo'] as String?,
          ),
        );
      }
      final last = history.lastOrNull;
      final at =
          closedAt ??
          (last?.stage == currentStage ? last?.occurredAt : null) ??
          DateTime.tryParse(current?['creado_en'] as String? ?? '') ??
          last?.occurredAt;
      if (at != null) {
        final entry = HelpRequestHistoryEntry(
          requestId: id,
          version: version,
          stage: currentStage,
          occurredAt: at,
          reason: useCache
              ? cached['motivo'] as String?
              : last?.stage == currentStage
              ? last?.reason
              : null,
        );
        if (last?.stage == currentStage) history.removeLast();
        history.add(entry);
        if (closedAt != null &&
            !useCache &&
            (entry.reason != null || currentStage == HelpRequestStage.attended)) {
          closed = entry;
        }
      }
    }
    return (
      state: OwnHelpRequestState(requestId: id, submission: submission, history: history),
      closed: closed,
      archived: useCache,
    );
  });
}
