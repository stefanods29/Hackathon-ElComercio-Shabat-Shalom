/// Emergency directory of a district (Phase 1, Lot A, part 2): only institutional data, never
/// neighbors. `contracts/directorio-emergencia.schema.json` is the contract; the API validates it
/// again with 422 `directorio_invalido`, these checks only give feedback while typing.
library;

enum EntryType {
  number('numero'),
  meetingPoint('punto_de_encuentro'),
  healthCenter('centro_de_salud'),
  shelter('albergue');

  const EntryType(this.code);

  final String code;

  static EntryType? fromCode(String code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

class EntryLocation {
  const EntryLocation({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

class DirectoryEntry {
  const DirectoryEntry({
    required this.id,
    required this.type,
    required this.name,
    this.phone,
    this.location,
    this.address,
    this.description,
    required this.sourceName,
    this.sourceUrl,
    required this.verifiedOn,
  });

  factory DirectoryEntry.fromJson(Map<String, Object?> json) {
    final type = EntryType.fromCode('${json['tipo']}');
    final source = json['fuente'];
    final location = json['ubicacion'];
    if (type == null || source is! Map) throw const FormatException('Entrada inválida.');
    return DirectoryEntry(
      id: '${json['id']}',
      type: type,
      name: '${json['nombre']}',
      phone: json['telefono'] as String?,
      location: location is Map
          ? EntryLocation(
              lat: (location['lat'] as num).toDouble(),
              lng: (location['lng'] as num).toDouble(),
            )
          : null,
      address: json['direccion'] as String?,
      description: json['descripcion'] as String?,
      sourceName: '${source['nombre']}',
      sourceUrl: source['url'] as String?,
      verifiedOn: '${json['verificadoEn']}',
    );
  }

  final String id;
  final EntryType type;
  final String name;
  final String? phone;
  final EntryLocation? location;
  final String? address;
  final String? description;
  final String sourceName;
  final String? sourceUrl;

  /// Last day the curator checked the entry against its source (`YYYY-MM-DD`).
  final String verifiedOn;

  /// Same keys as the schema; optional fields that are empty are left out.
  Map<String, Object?> toJson() => {
    'id': id,
    'tipo': type.code,
    'nombre': name,
    if (phone case final value? when value.isNotEmpty) 'telefono': value,
    if (location case final point?) 'ubicacion': {'lat': point.lat, 'lng': point.lng},
    if (address case final value? when value.isNotEmpty) 'direccion': value,
    if (description case final value? when value.isNotEmpty) 'descripcion': value,
    'fuente': {
      'nombre': sourceName,
      if (sourceUrl case final value? when value.isNotEmpty) 'url': value,
    },
    'verificadoEn': verifiedOn,
  };
}

class EmergencyDirectory {
  const EmergencyDirectory({
    required this.version,
    required this.district,
    required this.generatedAt,
    required this.entries,
  });

  final int version;
  final String district;
  final DateTime generatedAt;
  final List<DirectoryEntry> entries;
}

/// A published file as the API returns it, with the hash the app checks before saving it.
class PublishedDirectory {
  const PublishedDirectory({
    required this.file,
    required this.sha256,
    required this.bytes,
    required this.directory,
  });

  final String file;
  final String sha256;
  final int bytes;
  final EmergencyDirectory directory;
}

class DirectorySummary {
  const DirectorySummary({
    required this.id,
    required this.file,
    required this.version,
    required this.sha256,
    required this.bytes,
    required this.zones,
  });

  final String id;
  final String file;
  final int version;
  final String sha256;
  final int bytes;
  final List<String> zones;
}

/// Port to the curation routes of this change (`/v1/operacion/directorio-emergencia`).
abstract interface class CurationRepository {
  Future<List<DirectorySummary>> list();

  Future<PublishedDirectory> get(String file);

  /// Publishes version `seenVersion + 1`, or fails with 409 `conflicto_de_version`.
  Future<PublishedDirectory> publish(
    String file, {
    required int seenVersion,
    required String district,
    required List<DirectoryEntry> entries,
    required String idempotencyKey,
  });
}

final fileNamePattern = RegExp(r'^[a-z0-9-]{2,60}\.json$');
final _idPattern = RegExp(r'^[a-z0-9-]{2,60}$');
final _phonePattern = RegExp(r'^\+?[0-9][0-9 ]{1,18}[0-9]$');
final _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

enum EntryProblemKind {
  idFormat,
  idRepeated,
  nameLength,
  phoneRequired,
  phoneFormat,
  locationRequired,
  latitudeRange,
  longitudeRange,
  addressLength,
  descriptionLength,
  sourceNameLength,
  sourceUrlHttps,
  verifiedFormat,
  verifiedFuture,
}

/// A local problem, with the same dotted path the API uses (`telefono`, `fuente.url`…).
class EntryProblem {
  const EntryProblem(this.field, this.kind);

  final String field;
  final EntryProblemKind kind;
}

bool _length(String? value, int min, int max) =>
    value != null && value.trim().length >= min && value.trim().length <= max;

bool _optionalLength(String? value, int min, int max) =>
    value == null || value.isEmpty || _length(value, min, max);

/// Checks of the JSON Schema plus the API's own rules (unique id, no verification in the future).
/// [today] is `YYYY-MM-DD` in the pilot's calendar.
List<EntryProblem> validateEntry(
  DirectoryEntry entry, {
  required String today,
  Iterable<String> otherIds = const [],
}) {
  final problems = <EntryProblem>[];
  void add(String field, EntryProblemKind kind) => problems.add(EntryProblem(field, kind));

  if (!_idPattern.hasMatch(entry.id)) add('id', EntryProblemKind.idFormat);
  if (otherIds.contains(entry.id)) add('id', EntryProblemKind.idRepeated);
  if (!_length(entry.name, 2, 120)) add('nombre', EntryProblemKind.nameLength);
  final phone = entry.phone;
  if (phone != null && phone.isNotEmpty && !_phonePattern.hasMatch(phone)) {
    add('telefono', EntryProblemKind.phoneFormat);
  }
  final location = entry.location;
  if (entry.type == EntryType.number) {
    if (phone == null || phone.isEmpty) add('telefono', EntryProblemKind.phoneRequired);
  } else if (location == null) {
    add('ubicacion', EntryProblemKind.locationRequired);
  }
  if (location != null) {
    if (location.lat < -90 || location.lat > 90) add('ubicacion.lat', EntryProblemKind.latitudeRange);
    if (location.lng < -180 || location.lng > 180) {
      add('ubicacion.lng', EntryProblemKind.longitudeRange);
    }
  }
  if (!_optionalLength(entry.address, 2, 200)) add('direccion', EntryProblemKind.addressLength);
  if (!_optionalLength(entry.description, 2, 300)) {
    add('descripcion', EntryProblemKind.descriptionLength);
  }
  if (!_length(entry.sourceName, 2, 120)) add('fuente.nombre', EntryProblemKind.sourceNameLength);
  final url = entry.sourceUrl;
  if (url != null && url.isNotEmpty) {
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty) {
      add('fuente.url', EntryProblemKind.sourceUrlHttps);
    }
  }
  if (!_dayPattern.hasMatch(entry.verifiedOn) || DateTime.tryParse(entry.verifiedOn) == null) {
    add('verificadoEn', EntryProblemKind.verifiedFormat);
  } else if (entry.verifiedOn.compareTo(today) > 0) {
    // ISO dates compare correctly as text.
    add('verificadoEn', EntryProblemKind.verifiedFuture);
  }
  return problems;
}

/// Problems of every entry, by position, with ids compared across the whole directory.
Map<int, List<EntryProblem>> validateEntries(List<DirectoryEntry> entries, {required String today}) {
  final result = <int, List<EntryProblem>>{};
  for (var index = 0; index < entries.length; index++) {
    final others = [
      for (var other = 0; other < index; other++) entries[other].id,
    ];
    final problems = validateEntry(entries[index], today: today, otherIds: others);
    if (problems.isNotEmpty) result[index] = problems;
  }
  return result;
}

bool districtIsValid(String district) => _length(district, 2, 80);

const maxEntries = 500;

/// `Municipalidad de Lince` → `municipalidad-de-lince`, a starting id for a new entry.
String suggestId(String name) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n'};
  final lower = name.toLowerCase().split('').map((char) => accents[char] ?? char).join();
  final slug = lower
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.length > 60 ? slug.substring(0, 60).replaceAll(RegExp(r'-+$'), '') : slug;
}
