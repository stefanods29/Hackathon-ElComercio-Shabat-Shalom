import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/network/problem_details.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/features/curaduria/domain/directory.dart';

final curationRepositoryProvider = Provider<CurationRepository?>((ref) {
  if (ref.watch(currentOperatorProvider) == null) return null;
  if (ref.watch(demoDataProvider)) return DemoCurationRepository(now: ref.watch(clockProvider));
  return HttpCurationRepository(ref.watch(consoleApiProvider));
});

final directoriesProvider = FutureProvider.autoDispose<List<DirectorySummary>>((ref) async {
  final repository = ref.watch(curationRepositoryProvider);
  if (repository == null) throw const ModuleNotAvailable();
  return repository.list();
});

/// Routes of `contracts/openapi.yaml` (tag `curaduria`).
class HttpCurationRepository implements CurationRepository {
  HttpCurationRepository(this._api);

  final ConsoleApi _api;

  static const _base = '/v1/operacion/directorio-emergencia';

  @override
  Future<List<DirectorySummary>> list() async {
    final body = await _api.getJson(_base);
    return [
      for (final row in objects(body, 'datos'))
        DirectorySummary(
          id: field<String>(row, 'id'),
          file: field<String>(row, 'archivo'),
          version: field<int>(row, 'version'),
          sha256: field<String>(row, 'sha256'),
          bytes: field<int>(row, 'bytes'),
          zones: [
            for (final zone in field<List<Object?>>(row, 'zonas'))
              if (zone is String) zone,
          ],
        ),
    ];
  }

  @override
  Future<PublishedDirectory> get(String file) async =>
      _published(await _api.getJson('$_base/${Uri.encodeComponent(file)}'));

  @override
  Future<PublishedDirectory> publish(
    String file, {
    required int seenVersion,
    required String district,
    required List<DirectoryEntry> entries,
    required String idempotencyKey,
  }) async {
    final body = await _api.putJson(
      '$_base/${Uri.encodeComponent(file)}',
      body: {
        'versionVista': seenVersion,
        'distrito': district,
        'entradas': [for (final entry in entries) entry.toJson()],
      },
      idempotencyKey: idempotencyKey,
      expected: const {200},
    );
    return _published(body);
  }

  static PublishedDirectory _published(Map<String, Object?> body) {
    final directory = field<Map<Object?, Object?>>(body, 'directorio');
    final json = Map<String, Object?>.from(directory);
    try {
      return PublishedDirectory(
        file: field<String>(body, 'archivo'),
        sha256: field<String>(body, 'sha256'),
        bytes: field<int>(body, 'bytes'),
        directory: EmergencyDirectory(
          version: field<int>(json, 'version'),
          district: field<String>(json, 'distrito'),
          generatedAt: instant(json, 'generadoEn'),
          entries: [for (final row in objects(json, 'entradas')) DirectoryEntry.fromJson(row)],
        ),
      );
    } on FormatException catch (error) {
      throw UnexpectedResponse(error.message);
    } on TypeError {
      throw const UnexpectedResponse('Directorio inválido.');
    }
  }
}

/// A fictitious district for `CONSOLE_DATA=demo`, with the same rules as the API: validation
/// (422 `directorio_invalido`), `versionVista` (409) and idempotency.
class DemoCurationRepository implements CurationRepository {
  DemoCurationRepository({required this.now}) {
    _files['distrito-de-ejemplo.json'] = PublishedDirectory(
      file: 'distrito-de-ejemplo.json',
      sha256: '0' * 64,
      bytes: 1024,
      directory: EmergencyDirectory(
        version: 3,
        district: 'Distrito de ejemplo',
        generatedAt: now().subtract(const Duration(days: 2)),
        entries: const [
          DirectoryEntry(
            id: 'serenazgo-ejemplo',
            type: EntryType.number,
            name: 'Serenazgo (número ficticio)',
            phone: '01 000 0000',
            sourceName: 'Municipalidad de ejemplo',
            verifiedOn: '2026-11-01',
          ),
          DirectoryEntry(
            id: 'parque-central-ejemplo',
            type: EntryType.meetingPoint,
            name: 'Parque central (ejemplo)',
            location: EntryLocation(lat: -12.0822, lng: -77.0371),
            address: 'Dirección ficticia 123',
            sourceName: 'Defensa Civil de ejemplo',
            sourceUrl: 'https://example.org/defensa-civil',
            verifiedOn: '2026-10-20',
          ),
          DirectoryEntry(
            id: 'centro-de-salud-ejemplo',
            type: EntryType.healthCenter,
            name: 'Centro de salud (ejemplo)',
            location: EntryLocation(lat: -12.0875, lng: -77.0330),
            sourceName: 'Red de salud de ejemplo',
            verifiedOn: '2026-10-15',
          ),
        ],
      ),
    );
  }

  final DateTime Function() now;
  final _files = <String, PublishedDirectory>{};
  final _replies = <String, PublishedDirectory>{};

  Future<void> _latency() => Future<void>.delayed(const Duration(milliseconds: 250));

  @override
  Future<List<DirectorySummary>> list() async {
    await _latency();
    return [
      for (final published in _files.values)
        DirectorySummary(
          id: published.file.replaceAll('.json', ''),
          file: published.file,
          version: published.directory.version,
          sha256: published.sha256,
          bytes: published.bytes,
          zones: const ['00000000-0000-4000-8000-0000000000a1'],
        ),
    ];
  }

  @override
  Future<PublishedDirectory> get(String file) async {
    await _latency();
    final published = _files[file];
    if (published == null) throw demoProblem(404, 'recurso_no_encontrado');
    return published;
  }

  @override
  Future<PublishedDirectory> publish(
    String file, {
    required int seenVersion,
    required String district,
    required List<DirectoryEntry> entries,
    required String idempotencyKey,
  }) async {
    await _latency();
    final replay = _replies[idempotencyKey];
    if (replay != null) return replay;
    final current = _files[file];
    if (current == null) throw demoProblem(404, 'recurso_no_encontrado');
    if (current.directory.version != seenVersion) throw demoProblem(409, 'conflicto_de_version');
    final problems = validateEntries(entries, today: isoDay(now()));
    if (!districtIsValid(district) || entries.isEmpty || problems.isNotEmpty) {
      throw ApiProblem(
        ProblemDetails(
          status: 422,
          title: 'No se pudo procesar',
          code: 'directorio_invalido',
          fieldErrors: [
            for (final MapEntry(key: index, value: list) in problems.entries)
              for (final problem in list)
                FieldError('entradas.$index.${problem.field}', 'Revisa este dato.'),
          ],
        ),
      );
    }
    final published = PublishedDirectory(
      file: file,
      sha256: current.sha256,
      bytes: current.bytes,
      directory: EmergencyDirectory(
        version: seenVersion + 1,
        district: district,
        generatedAt: now(),
        entries: List.unmodifiable(entries),
      ),
    );
    _files[file] = published;
    return _replies[idempotencyKey] = published;
  }
}
