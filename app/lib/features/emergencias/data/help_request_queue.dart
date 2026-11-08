import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/submission_row.dart';

/// Uses the active account's encrypted outbox. The caller keeps the IDs with the draft.
class HelpRequestQueue {
  HelpRequestQueue(LocalSyncDatabase local, {DateTime Function()? clock})
    : _database = local.database,
      _clock = clock ?? DateTime.now;

  final PowerSyncDatabase _database;
  final DateTime Function() _clock;
  static const _kind = SubmissionKind.helpRequest;

  Stream<Submission?> watch(String requestId) => _database
      .watch(
        'SELECT * FROM envios WHERE tipo = ? AND recurso_id = ?',
        parameters: [_kind.name, requestId.toLowerCase()],
        triggerOnTables: ['envios'],
      )
      .map((rows) => rows.isEmpty ? null : submissionFromRow(rows.single));

  Future<Submission> save({
    required String requestId,
    required String idempotencyKey,
    required Map<String, Object?> body,
  }) {
    final id = _canonicalV7(requestId);
    final key = _canonicalV7(idempotencyKey);
    return _database.writeTransaction((tx) async {
      final existing = await tx.getOptional(
        'SELECT * FROM envios WHERE tipo = ? AND recurso_id = ?',
        [_kind.name, id],
      );
      if (existing != null) return submissionFromRow(existing);

      final reusedKey = await tx.getOptional(
        'SELECT id FROM envios WHERE clave_idempotencia = ? LIMIT 1',
        [key],
      );
      if (reusedKey != null) throw StateError('La clave de envío ya está en uso.');
      return enqueueSubmission(
        tx,
        Submission(
          id: newLocalId(),
          kind: _kind,
          resourceId: id,
          idempotencyKey: key,
          createdAt: _clock(),
        ),
        {...body, 'id': id},
      );
    });
  }

  static String _canonicalV7(String value) {
    if (value.length != 36 || value[14] != '7' || !Uuid.isValidUUID(fromString: value)) {
      throw const FormatException('Identificador de pedido inválido.');
    }
    return value.toLowerCase();
  }
}
