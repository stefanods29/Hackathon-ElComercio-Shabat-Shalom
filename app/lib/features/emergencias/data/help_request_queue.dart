import 'package:powersync/powersync.dart';
import 'package:uuid/uuid.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/sync/command_queue.dart';
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
    required HelpRequestPayload body,
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
      return enqueueCommand(
        tx,
        kind: _kind,
        resourceId: id,
        idempotencyKey: key,
        now: _clock(),
        body: body.toJson(id),
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

enum HelpRequestNeed {
  water('agua'),
  food('alimentos'),
  medicine('medicamentos'),
  transport('traslado'),
  shelter('albergue'),
  other('otro');

  const HelpRequestNeed(this.apiValue);
  final String apiValue;
}

enum HelpRequestPriority {
  high('alta'),
  medium('media'),
  low('baja');

  const HelpRequestPriority(this.apiValue);
  final String apiValue;
}

/// Only the encrypted outbox holds this payload. The status repository reads metadata separately.
class HelpRequestPayload {
  const HelpRequestPayload({
    required this.eventId,
    required this.need,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.priority = HelpRequestPriority.medium,
    this.lifeThreatening = false,
  });

  final String eventId;
  final HelpRequestNeed need;
  final String description;
  final double latitude;
  final double longitude;
  final HelpRequestPriority priority;
  final bool lifeThreatening;

  Map<String, Object?> toJson(String id) {
    final trimmedDescription = description.trim();
    if (!Uuid.isValidUUID(fromString: eventId) ||
        trimmedDescription.isEmpty ||
        trimmedDescription.runes.length > 2000 ||
        !latitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        !longitude.isFinite ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Datos del pedido inválidos.');
    }
    return {
      'id': id,
      'eventoId': eventId,
      'necesidad': need.apiValue,
      'prioridad': priority.apiValue,
      'descripcion': trimmedDescription,
      'ubicacion': {'lat': latitude, 'lng': longitude},
      'riesgoVital': lifeThreatening,
    };
  }
}
