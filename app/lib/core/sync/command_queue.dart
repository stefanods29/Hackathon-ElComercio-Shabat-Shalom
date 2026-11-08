import 'dart:convert';

import 'package:sqlite_async/sqlite_async.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/submissions/submission.dart';

/// Saves a neighbor's action in the upload queue inside the caller's local transaction:
/// the command (uploaded by PowerSync) and its visible submission state ("Guardado en tu
/// celular"). The idempotency key is generated once and reused on every retry.
Future<Submission> enqueueCommand(
  SqliteWriteContext tx, {
  required SubmissionKind kind,
  required String resourceId,
  required DateTime now,
  required Map<String, Object?> body,
  Map<String, Object?>? optimistic,
}) async {
  final submission = Submission(
    id: newLocalId(),
    kind: kind,
    resourceId: resourceId,
    idempotencyKey: newLocalId(),
    createdAt: now,
  );
  await tx.execute(
    'INSERT INTO comandos (id, tipo, recurso_id, cuerpo, clave_idempotencia) VALUES (?, ?, ?, ?, ?)',
    [submission.id, kind.name, resourceId, jsonEncode(body), submission.idempotencyKey],
  );
  await tx.execute(
    '''
    INSERT INTO envios (id, tipo, recurso_id, clave_idempotencia, estado, intentos, creado_en, optimista)
    VALUES (?, ?, ?, ?, ?, 0, ?, ?)
    ''',
    [
      submission.id,
      kind.name,
      resourceId,
      submission.idempotencyKey,
      submission.status.name,
      now.toUtc().toIso8601String(),
      optimistic == null ? null : jsonEncode(optimistic),
    ],
  );
  return submission;
}

/// Latest submission row of each resource among [kinds], oldest first inside each resource.
///
/// [rows] must be ordered by `creado_en, id`; the last one per `recurso_id` wins.
Map<String, Map<String, Object?>> latestSubmissionByResource(
  Iterable<Map<String, Object?>> rows,
  Set<SubmissionKind> kinds,
) {
  final names = {for (final kind in kinds) kind.name};
  final latest = <String, Map<String, Object?>>{};
  for (final row in rows) {
    if (names.contains(row['tipo'])) latest[row['recurso_id'] as String] = row;
  }
  return latest;
}
