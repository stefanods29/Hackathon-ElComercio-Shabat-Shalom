import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/command_queue.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/domain/reputation_repository.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart' show LocalValidationError;

/// Reviews, Visto Bueno and reports over the encrypted PowerSync database (Phase 1, Lot A part 1).
class PowerSyncReputationRepository implements ReputationRepository {
  PowerSyncReputationRepository(
    this._database, {
    required this.neighborId,
    required this.zoneId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PowerSyncDatabase _database;
  final String neighborId;
  final String zoneId;
  final DateTime Function() _clock;

  static const _endorsementKinds = {
    SubmissionKind.giveEndorsement,
    SubmissionKind.withdrawEndorsement,
  };

  static const _publishedSql = r'''
    SELECT r.id, r.servicio_id, r.calificacion, r.comentario, r.publicada_en,
           EXISTS (SELECT 1 FROM mis_resenas AS m WHERE m.id = r.id) AS es_mia,
           (SELECT json_group_array(json_object(
              'id', f.id, 'resena_id', f.resena_id, 'archivo_id', f.archivo_id, 'orden', f.orden,
              'ancho', f.ancho, 'alto', f.alto, 'blurhash', f.blurhash))
            FROM fotos_resena AS f WHERE f.resena_id = r.id) AS fotos
    FROM resenas AS r
    WHERE r.servicio_id = ?
    ORDER BY r.publicada_en DESC, r.id
  ''';

  static const _myReviewsSql = r'''
    SELECT 'fila' AS fuente, id AS recurso_id, json_object(
             'id', id, 'servicio_id', servicio_id, 'calificacion', calificacion,
             'comentario', comentario, 'estado', estado, 'motivo_estado', motivo_estado,
             'creado_en', creado_en, 'actualizado_en', actualizado_en) AS datos,
           NULL AS tipo, NULL AS estado, NULL AS creado_en, NULL AS envio_id
    FROM mis_resenas
    UNION ALL
    SELECT 'envio', recurso_id, optimista, tipo, estado, creado_en, id
    FROM envios WHERE tipo = 'writeReview'
  ''';

  static const _endorsementsSql = r'''
    SELECT 'fila' AS fuente, servicio_id AS recurso_id, creado_en AS datos,
           NULL AS tipo, NULL AS estado, NULL AS creado_en, NULL AS envio_id
    FROM mis_vistos_buenos
    UNION ALL
    SELECT 'envio', recurso_id, optimista, tipo, estado, creado_en, id
    FROM envios WHERE tipo IN ('giveEndorsement', 'withdrawEndorsement')
  ''';

  @override
  Stream<List<Review>> watchPublishedReviews(String serviceId) => _database
      .watch(
        _publishedSql,
        parameters: [serviceId],
        triggerOnTables: ['resenas', 'fotos_resena', 'mis_resenas'],
      )
      .map(
        (rows) => rows
            .map(
              (row) => Review(
                id: row['id'] as String,
                serviceId: row['servicio_id'] as String,
                rating: _int(row['calificacion']),
                comment: row['comentario'] as String?,
                status: ReviewStatus.published,
                publishedAt: _date(row['publicada_en']),
                photos: _photos(row['fotos']),
                isMine: _int(row['es_mia']) == 1,
              ),
            )
            .toList(growable: false),
      );

  @override
  Stream<List<Review>> watchMyReviews() =>
      _database.watch(_myReviewsSql, triggerOnTables: ['mis_resenas', 'envios']).map((rows) {
        final reviews = _mergeMyReviews(rows);
        return reviews.values.toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      });

  @override
  Stream<List<Endorsement>> watchMyEndorsements() => _database
      .watch(_endorsementsSql, triggerOnTables: ['mis_vistos_buenos', 'envios'])
      .map((rows) => _mergeEndorsements(rows).values.toList(growable: false));

  @override
  Future<Submission> writeReview(NewReview review) => _database.writeTransaction((tx) async {
    await _requireOthersService(
      tx,
      review.serviceId,
      ownMessage: 'No puedes reseñar tu propio servicio.',
    );
    final mine = _mergeMyReviews(await tx.getAll(_myReviewsSql));
    if (mine.values.any((existing) => existing.serviceId == review.serviceId)) {
      throw const LocalValidationError('Ya reseñaste este servicio.');
    }
    final id = newLocalId();
    final now = _clock().toUtc().toIso8601String();
    return enqueueCommand(
      tx,
      kind: SubmissionKind.writeReview,
      resourceId: id,
      now: _clock(),
      body: {
        'id': id,
        'servicioId': review.serviceId,
        'calificacion': review.rating,
        'comentario': review.comment,
        'fotos': review.photoFileIds,
      },
      optimistic: {
        'id': id,
        'servicio_id': review.serviceId,
        'calificacion': review.rating,
        'comentario': review.comment,
        'estado': ReviewStatus.inReview.apiValue,
        'motivo_estado': null,
        'creado_en': now,
        'actualizado_en': now,
      },
    );
  });

  @override
  Future<Submission> giveEndorsement(String serviceId) => _database.writeTransaction((tx) async {
    await _requireOthersService(
      tx,
      serviceId,
      ownMessage: 'No puedes dar Visto Bueno a tu propio servicio.',
    );
    final current = _mergeEndorsements(await tx.getAll(_endorsementsSql));
    if (current.containsKey(serviceId)) {
      throw const LocalValidationError('Ya diste tu Visto Bueno a este servicio.');
    }
    final now = _clock();
    return enqueueCommand(
      tx,
      kind: SubmissionKind.giveEndorsement,
      resourceId: serviceId,
      now: now,
      body: const {},
      optimistic: {'servicio_id': serviceId, 'creado_en': now.toUtc().toIso8601String()},
    );
  });

  @override
  Future<Submission> withdrawEndorsement(String serviceId) =>
      _database.writeTransaction((tx) async {
        final current = _mergeEndorsements(await tx.getAll(_endorsementsSql));
        if (!current.containsKey(serviceId)) {
          throw const LocalValidationError('No diste tu Visto Bueno a este servicio.');
        }
        return enqueueCommand(
          tx,
          kind: SubmissionKind.withdrawEndorsement,
          resourceId: serviceId,
          now: _clock(),
          body: const {},
          optimistic: {'servicio_id': serviceId, 'retirado': true},
        );
      });

  @override
  Future<Submission> report(NewReport report) => _database.writeTransaction((tx) {
    final id = newLocalId();
    return enqueueCommand(
      tx,
      kind: SubmissionKind.report,
      resourceId: id,
      now: _clock(),
      body: {
        'id': id,
        'tipoContenido': report.content.apiValue,
        'contenidoId': report.contentId,
        'motivo': report.reason.apiValue,
        'detalle': report.detail,
      },
    );
  });

  /// The service must be on the phone, in the zone, and belong to someone else.
  Future<void> _requireOthersService(
    SqliteReadContext tx,
    String serviceId, {
    required String ownMessage,
  }) async {
    final service = await tx.getOptional(
      'SELECT proveedor_id FROM servicios WHERE id = ? AND zona_id = ?',
      [serviceId, zoneId],
    );
    if (service == null) throw const LocalValidationError('Este servicio ya no está disponible.');
    if (service['proveedor_id'] == neighborId) throw LocalValidationError(ownMessage);
  }

  Map<String, Review> _mergeMyReviews(Iterable<Map<String, Object?>> rows) {
    final downloaded = <String, Map<String, Object?>>{};
    final commands = <Map<String, Object?>>[];
    for (final row in rows) {
      if (row['fuente'] == 'fila') {
        downloaded[row['recurso_id'] as String] =
            jsonDecode(row['datos'] as String) as Map<String, Object?>;
      } else {
        commands.add(row);
      }
    }
    final latest = latestSubmissionByResource(_sorted(commands), {SubmissionKind.writeReview});
    final result = <String, Review>{};
    for (final id in {...downloaded.keys, ...latest.keys}) {
      final command = latest[id];
      final status = _status(command?['estado']);
      final overlay = command?['datos'] as String?;
      final row =
          downloaded[id] ??
          (status == SubmissionStatus.savedOnPhone && overlay != null
              ? jsonDecode(overlay) as Map<String, Object?>
              : null);
      if (row == null) continue;
      result[id] = Review(
        id: id,
        serviceId: row['servicio_id'] as String,
        rating: _int(row['calificacion']),
        comment: row['comentario'] as String?,
        status: ReviewStatus.fromApi(row['estado'] as String),
        statusReason: row['motivo_estado'] as String?,
        createdAt: _date(row['creado_en']),
        isMine: true,
        submissionStatus: status,
      );
    }
    return result;
  }

  Map<String, Endorsement> _mergeEndorsements(Iterable<Map<String, Object?>> rows) {
    final downloaded = <String, String?>{};
    final commands = <Map<String, Object?>>[];
    for (final row in rows) {
      if (row['fuente'] == 'fila') {
        downloaded[row['recurso_id'] as String] = row['datos'] as String?;
      } else {
        commands.add(row);
      }
    }
    final latest = latestSubmissionByResource(_sorted(commands), _endorsementKinds);
    final result = <String, Endorsement>{};
    for (final serviceId in {...downloaded.keys, ...latest.keys}) {
      final command = latest[serviceId];
      final status = _status(command?['estado']);
      final pending = status == SubmissionStatus.savedOnPhone && command?['datos'] != null;
      final present = pending
          ? command!['tipo'] == SubmissionKind.giveEndorsement.name
          : downloaded.containsKey(serviceId);
      if (!present) continue;
      result[serviceId] = Endorsement(
        serviceId: serviceId,
        createdAt: _date(downloaded[serviceId]),
        submissionStatus: status,
      );
    }
    return result;
  }

  static List<Map<String, Object?>> _sorted(Iterable<Map<String, Object?>> commands) =>
      commands.toList()..sort((a, b) {
        final byTime = (a['creado_en'] as String).compareTo(b['creado_en'] as String);
        return byTime != 0 ? byTime : (a['envio_id'] as String).compareTo(b['envio_id'] as String);
      });

  static List<ReviewPhoto> _photos(Object? value) {
    if (value is! String) return const [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return const [];
    final photos = [
      for (final item in decoded.whereType<Map<String, Object?>>())
        if (item['id'] != null)
          ReviewPhoto(
            id: item['id'] as String,
            reviewId: item['resena_id'] as String,
            fileId: item['archivo_id'] as String,
            order: _int(item['orden']),
            width: item['ancho'] == null ? null : _int(item['ancho']),
            height: item['alto'] == null ? null : _int(item['alto']),
            blurhash: item['blurhash'] as String?,
          ),
    ];
    return photos..sort((a, b) => a.order.compareTo(b.order));
  }

  static SubmissionStatus _status(Object? value) =>
      value == null ? SubmissionStatus.sent : SubmissionStatus.values.byName(value as String);

  static int _int(Object? value) => switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text) ?? 0,
    _ => 0,
  };

  static DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;
}
