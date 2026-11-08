import 'dart:convert';

import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/command_queue.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/domain/search.dart';
import 'package:vecinal/features/directorio/domain/service_directory_repository.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart' show LocalValidationError;

/// Services directory over the encrypted PowerSync database (Phase 1, Lot A part 1).
///
/// Reads combine the downloaded rows with the optimistic overlay of the latest pending command of
/// each service; writes save the overlay, the command and its submission in one local
/// transaction, like `PowerSyncPostRepository`.
class PowerSyncServiceDirectoryRepository implements ServiceDirectoryRepository {
  PowerSyncServiceDirectoryRepository(
    this._database, {
    required this.neighborId,
    required this.zoneId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final PowerSyncDatabase _database;
  final String neighborId;
  final String zoneId;
  final DateTime Function() _clock;

  static const _serviceKinds = {
    SubmissionKind.publishService,
    SubmissionKind.updateService,
    SubmissionKind.withdrawService,
  };

  // Downloaded services of the zone and service commands, in a single SQLite snapshot.
  static const _servicesSql = r'''
    SELECT 'fila' AS fuente, id AS recurso_id, json_object(
             'id', id, 'proveedor_id', proveedor_id, 'zona_id', zona_id,
             'categoria_id', categoria_id, 'titulo', titulo, 'descripcion', descripcion,
             'lat', lat, 'lng', lng, 'radio_cobertura_m', radio_cobertura_m,
             'disponible_en_emergencia', disponible_en_emergencia, 'atributos', atributos,
             'total_resenas', total_resenas, 'promedio', promedio,
             'puntaje_ranking', puntaje_ranking,
             'vistos_buenos_de_la_zona', vistos_buenos_de_la_zona, 'version', version,
             'actualizado_en', actualizado_en) AS datos,
           NULL AS tipo, NULL AS estado, NULL AS creado_en, NULL AS envio_id
    FROM servicios WHERE zona_id = ?
    UNION ALL
    SELECT 'envio', recurso_id, optimista, tipo, estado, creado_en, id
    FROM envios WHERE tipo IN ('publishService', 'updateService', 'withdrawService')
  ''';

  static const _providerSql = r'''
    SELECT p.id, p.nombre_publico, p.descripcion, p.actualizado_en, e.optimista, e.estado
    FROM (SELECT ?1 AS pid) AS q
    LEFT JOIN proveedores AS p ON p.id = q.pid
    LEFT JOIN (
      SELECT optimista, estado FROM envios
      WHERE tipo = 'upsertProvider' AND recurso_id = ?1
      ORDER BY creado_en DESC, id DESC LIMIT 1
    ) AS e
  ''';

  @override
  Stream<List<Category>> watchCategories() => _database
      .watch('SELECT * FROM categorias ORDER BY orden, nombre', triggerOnTables: ['categorias'])
      .map((rows) => rows.map(_category).toList(growable: false));

  Stream<List<Service>> _watchZoneServices() => _database
      .watch(_servicesSql, parameters: [zoneId], triggerOnTables: ['servicios', 'envios'])
      .map(_mergeServices);

  @override
  Stream<List<Service>> watchServices([ServiceQuery query = const ServiceQuery()]) =>
      _watchZoneServices().map((services) => filterAndSortServices(services, query));

  @override
  Stream<Service?> watchService(String serviceId) => _watchZoneServices().map(
    (services) => services.where((service) => service.id == serviceId).firstOrNull,
  );

  @override
  Stream<List<Service>> watchProviderServices(String providerId) => _watchZoneServices().map(
    (services) => filterAndSortServices(
      services.where((service) => service.providerId == providerId),
      const ServiceQuery(),
    ),
  );

  @override
  Stream<ProviderProfile?> watchProvider(String providerId) => _database
      .watch(_providerSql, parameters: [providerId], triggerOnTables: ['proveedores', 'envios'])
      .map((rows) {
        final row = rows.single;
        final status = _status(row['estado']);
        final overlay = row['optimista'] as String?;
        if (status == SubmissionStatus.savedOnPhone && overlay != null) {
          return _provider(jsonDecode(overlay) as Map<String, Object?>, status);
        }
        if (row['id'] == null) return null;
        return _provider(row, status);
      });

  @override
  Future<Submission> upsertProvider({required String publicName, String? description}) =>
      _database.writeTransaction((tx) {
        final now = _clock();
        return enqueueCommand(
          tx,
          kind: SubmissionKind.upsertProvider,
          resourceId: neighborId,
          now: now,
          body: {'nombrePublico': publicName, 'descripcion': description},
          optimistic: {
            'id': neighborId,
            'nombre_publico': publicName,
            'descripcion': description,
            'actualizado_en': now.toUtc().toIso8601String(),
          },
        );
      });

  @override
  Future<Submission> publishService(ServiceDraft draft) => _database.writeTransaction((tx) {
    final id = newLocalId();
    final now = _clock();
    return enqueueCommand(
      tx,
      kind: SubmissionKind.publishService,
      resourceId: id,
      now: now,
      body: {'id': id, ..._draftBody(draft)},
      optimistic: _optimisticRow(id: id, draft: draft, version: 1, now: now),
    );
  });

  @override
  Future<Submission> updateService({
    required String serviceId,
    required int seenVersion,
    required ServiceDraft changes,
  }) => _database.writeTransaction((tx) async {
    final current = await _ownCurrentService(tx, serviceId);
    final now = _clock();
    return enqueueCommand(
      tx,
      kind: SubmissionKind.updateService,
      resourceId: serviceId,
      now: now,
      body: {'versionVista': seenVersion, ..._draftBody(changes)},
      optimistic: {
        ...current,
        ..._optimisticRow(id: serviceId, draft: changes, version: seenVersion + 1, now: now),
        'atributos': current['atributos'],
        'total_resenas': current['total_resenas'],
        'promedio': current['promedio'],
        'puntaje_ranking': current['puntaje_ranking'],
        'vistos_buenos_de_la_zona': current['vistos_buenos_de_la_zona'],
      },
    );
  });

  @override
  Future<Submission> withdrawService(String serviceId) => _database.writeTransaction((tx) async {
    await _ownCurrentService(tx, serviceId);
    return enqueueCommand(
      tx,
      kind: SubmissionKind.withdrawService,
      resourceId: serviceId,
      now: _clock(),
      body: const {},
      // A pending withdrawal hides the service from my lists right away.
      optimistic: {'id': serviceId, 'retirado': true},
    );
  });

  /// The service as this phone sees it, only if it belongs to the current neighbor.
  Future<Map<String, Object?>> _ownCurrentService(SqliteReadContext tx, String serviceId) async {
    final rows = await tx.getAll(_servicesSql, [zoneId]);
    final current = _mergeServiceRows(rows)[serviceId];
    if (current == null) {
      throw const LocalValidationError('Este servicio ya no está disponible.');
    }
    if (current['proveedor_id'] != neighborId) {
      throw const LocalValidationError('Solo puedes cambiar tus propios servicios.');
    }
    return current;
  }

  List<Service> _mergeServices(Iterable<Map<String, Object?>> rows) {
    final merged = _mergeServiceRows(rows);
    final statuses = _latestStatuses(rows);
    return [
      for (final entry in merged.entries)
        _service(entry.value, statuses[entry.key] ?? SubmissionStatus.sent),
    ];
  }

  /// Service rows by id after applying the overlay of each pending command.
  Map<String, Map<String, Object?>> _mergeServiceRows(Iterable<Map<String, Object?>> rows) {
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
    final latest = latestSubmissionByResource(_sorted(commands), _serviceKinds);
    final result = <String, Map<String, Object?>>{};
    for (final id in {...downloaded.keys, ...latest.keys}) {
      final row = downloaded[id];
      final command = latest[id];
      final overlay = command == null || command['datos'] == null
          ? null
          : jsonDecode(command['datos'] as String) as Map<String, Object?>;
      if (command != null && overlay != null && _status(command['estado']).isPending) {
        if (command['tipo'] == SubmissionKind.withdrawService.name) continue;
        final newer = row == null || _int(overlay['version']) > _int(row['version'], fallback: 0);
        if (newer && overlay['zona_id'] == zoneId) {
          result[id] = overlay;
          continue;
        }
      }
      if (row != null) result[id] = row;
    }
    return result;
  }

  Map<String, SubmissionStatus> _latestStatuses(Iterable<Map<String, Object?>> rows) {
    final commands = rows.where((row) => row['fuente'] == 'envio');
    return latestSubmissionByResource(
      _sorted(commands),
      _serviceKinds,
    ).map((id, row) => MapEntry(id, _status(row['estado'])));
  }

  static List<Map<String, Object?>> _sorted(Iterable<Map<String, Object?>> commands) =>
      commands.toList()..sort((a, b) {
        final byTime = (a['creado_en'] as String).compareTo(b['creado_en'] as String);
        return byTime != 0 ? byTime : (a['envio_id'] as String).compareTo(b['envio_id'] as String);
      });

  Map<String, Object?> _draftBody(ServiceDraft draft) => {
    'categoriaId': draft.categoryId,
    'titulo': draft.title,
    'descripcion': draft.description,
    'ubicacion': {'lat': draft.location.lat, 'lng': draft.location.lng},
    'muestraUbicacionExacta': draft.showExactLocation,
    'radioCoberturaM': draft.coverageRadiusMeters,
    'disponibleEnEmergencia': draft.availableInEmergency,
  };

  Map<String, Object?> _optimisticRow({
    required String id,
    required ServiceDraft draft,
    required int version,
    required DateTime now,
  }) {
    final public = draft.publicLocation;
    return {
      'id': id,
      'proveedor_id': neighborId,
      'zona_id': zoneId,
      'categoria_id': draft.categoryId,
      'titulo': draft.title,
      'descripcion': draft.description,
      'lat': public.lat,
      'lng': public.lng,
      'radio_cobertura_m': draft.coverageRadiusMeters,
      'disponible_en_emergencia': draft.availableInEmergency ? 1 : 0,
      'atributos': '{}',
      'total_resenas': 0,
      'promedio': 0,
      'puntaje_ranking': 0,
      'vistos_buenos_de_la_zona': 0,
      'version': version,
      'actualizado_en': now.toUtc().toIso8601String(),
    };
  }

  static SubmissionStatus _status(Object? value) =>
      value == null ? SubmissionStatus.sent : SubmissionStatus.values.byName(value as String);

  static int _int(Object? value, {int fallback = 0}) => switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text) ?? fallback,
    _ => fallback,
  };

  static double _double(Object? value) => switch (value) {
    final num number => number.toDouble(),
    final String text => double.tryParse(text) ?? 0,
    _ => 0,
  };

  static bool _bool(Object? value) =>
      value == true || value == 1 || value == '1' || value == 'true';

  static Map<String, Object?> _attributes(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is! String || value.isEmpty) return const {};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  static Category _category(Map<String, Object?> row) => Category(
    id: row['id'] as String,
    name: row['nombre'] as String? ?? '',
    icon: row['icono'] as String? ?? 'category',
    usefulInEmergency: _bool(row['util_en_emergencia']),
    order: _int(row['orden']),
  );

  static Service _service(Map<String, Object?> row, SubmissionStatus status) => Service(
    id: row['id'] as String,
    providerId: row['proveedor_id'] as String,
    zoneId: row['zona_id'] as String,
    categoryId: row['categoria_id'] as String,
    title: row['titulo'] as String,
    description: row['descripcion'] as String?,
    location: GeoPoint(_double(row['lat']), _double(row['lng'])),
    coverageRadiusMeters: _int(row['radio_cobertura_m'], fallback: 2000),
    availableInEmergency: _bool(row['disponible_en_emergencia']),
    attributes: _attributes(row['atributos']),
    reviewCount: _int(row['total_resenas']),
    averageRating: _double(row['promedio']),
    rankingScore: _double(row['puntaje_ranking']),
    zoneEndorsements: _int(row['vistos_buenos_de_la_zona']),
    version: _int(row['version'], fallback: 1),
    updatedAt: DateTime.parse(row['actualizado_en'] as String),
    submissionStatus: status,
  );

  static ProviderProfile _provider(Map<String, Object?> row, SubmissionStatus status) =>
      ProviderProfile(
        id: row['id'] as String,
        publicName: row['nombre_publico'] as String? ?? '',
        description: row['descripcion'] as String?,
        updatedAt: DateTime.parse(row['actualizado_en'] as String),
        submissionStatus: status,
      );
}

extension on SubmissionStatus {
  bool get isPending => this == SubmissionStatus.savedOnPhone;
}
