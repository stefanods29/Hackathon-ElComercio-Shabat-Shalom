import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/command_queue.dart';
import 'package:vecinal/core/sync/submission_row.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/domain/post_repository.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart';

class PowerSyncPostRepository implements PostRepository {
  PowerSyncPostRepository(
    this._database, {
    required this.neighborId,
    required this.zoneId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PowerSyncDatabase _database;
  final String neighborId;
  final String zoneId;
  final DateTime Function() _clock;

  // Select the wall and local optimistic actions in a single SQLite snapshot.
  static const _wallSql = r'''
    WITH latest AS (
      SELECT *, row_number() OVER (
        PARTITION BY recurso_id ORDER BY creado_en DESC, id DESC
      ) AS rn
      FROM envios
      WHERE tipo IN ('publish', 'takeFavor')
    )
    SELECT p.id, p.autor_id, p.zona_id, p.tipo, p.categoria, p.titulo, p.descripcion,
           p.estado, p.tomada_por_id, p.version, p.creado_en, p.actualizado_en,
           e.estado AS estado_envio, e.publicacion_optimista
    FROM publicaciones AS p LEFT JOIN latest AS e ON e.recurso_id = p.id AND e.rn = 1
    WHERE p.zona_id = ?
    UNION ALL
    SELECT e.recurso_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
           NULL, e.estado, e.publicacion_optimista
    FROM latest AS e
    WHERE e.rn = 1 AND e.tipo = 'publish' AND e.publicacion_optimista IS NOT NULL
      AND json_extract(e.publicacion_optimista, '$.zona_id') = ?
      AND NOT EXISTS (SELECT 1 FROM publicaciones AS p WHERE p.id = e.recurso_id)
  ''';

  @override
  Stream<List<Post>> watchWall() => _database
      .watch(_wallSql, parameters: [zoneId, zoneId], triggerOnTables: ['publicaciones', 'envios'])
      .map((rows) {
        final posts = rows.map((row) {
          final status = row['estado_envio'] as String?;
          final overlay = row['publicacion_optimista'] as String?;
          final optimistic = overlay == null ? null : jsonDecode(overlay) as Map<String, Object?>;
          final version = row['version'] as int?;
          final useOptimistic =
              optimistic != null && (version == null || (optimistic['version'] as int) > version);
          return _post(
            useOptimistic ? optimistic : row,
            status == null ? SubmissionStatus.sent : SubmissionStatus.values.byName(status),
          );
        }).toList();
        return posts..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });

  @override
  Stream<List<Submission>> watchActionsToReview() => _database
      .watch(
        '''
        SELECT * FROM envios
        WHERE tipo != 'helpRequest' AND estado = 'couldNotComplete'
        ORDER BY creado_en DESC, id DESC
        ''',
        triggerOnTables: ['envios'],
      )
      .map((rows) => rows.map(submissionFromRow).toList(growable: false));

  @override
  Future<Submission> publish(NewPost newPost) => _database.writeTransaction((tx) async {
    final id = newLocalId();
    final now = _clock();
    final body = {
      'id': id,
      'tipo': newPost.type.apiValue,
      'categoria': newPost.category,
      'titulo': newPost.title,
      'descripcion': newPost.description,
    };
    return _enqueue(tx, SubmissionKind.publish, id, now, body, {
      ...body,
      'autor_id': neighborId,
      'zona_id': zoneId,
      'estado': PostStatus.open.apiValue,
      'version': 1,
      'creado_en': now.toUtc().toIso8601String(),
      'actualizado_en': now.toUtc().toIso8601String(),
    });
  });

  @override
  Future<Submission> takeFavor({
    required String postId,
    required int seenVersion,
  }) => _database.writeTransaction((tx) async {
    final row = await tx.getOptional('SELECT * FROM publicaciones WHERE id = ? AND zona_id = ?', [
      postId,
      zoneId,
    ]);
    final pending = await tx.getOptional(
      'SELECT id FROM envios WHERE recurso_id = ? AND publicacion_optimista IS NOT NULL LIMIT 1',
      [postId],
    );
    if (row == null ||
        pending != null ||
        row['estado'] != PostStatus.open.apiValue ||
        row['version'] != seenVersion) {
      throw const LocalValidationError('Este favor ya no está disponible.');
    }
    if (row['autor_id'] == neighborId) {
      throw const LocalValidationError('No puedes tomar tu propia publicación.');
    }
    final now = _clock();
    return _enqueue(
      tx,
      SubmissionKind.takeFavor,
      postId,
      now,
      {'versionVista': seenVersion},
      {
        ...row,
        'estado': PostStatus.inProgress.apiValue,
        'tomada_por_id': neighborId,
        'version': seenVersion + 1,
        'actualizado_en': now.toUtc().toIso8601String(),
      },
    );
  });

  Future<Submission> _enqueue(
    SqliteWriteContext tx,
    SubmissionKind kind,
    String resourceId,
    DateTime now,
    Map<String, Object?> body,
    Map<String, Object?> optimistic,
  ) {
    return enqueueCommand(
      tx,
      kind: kind,
      resourceId: resourceId,
      now: now,
      body: body,
      optimisticPost: optimistic,
    );
  }

  Post _post(Map<String, Object?> row, SubmissionStatus status) => Post(
    id: row['id'] as String,
    authorId: row['autor_id'] as String,
    zoneId: row['zona_id'] as String,
    type: PostType.fromApi(row['tipo'] as String),
    category: row['categoria'] as String,
    title: row['titulo'] as String,
    description: row['descripcion'] as String?,
    status: PostStatus.fromApi(row['estado'] as String),
    takenById: row['tomada_por_id'] as String?,
    version: row['version'] as int,
    createdAt: DateTime.parse(row['creado_en'] as String),
    updatedAt: DateTime.parse(row['actualizado_en'] as String),
    submissionStatus: status,
  );
}
