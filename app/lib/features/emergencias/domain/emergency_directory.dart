import 'dart:convert';

/// Patterns and limits of `contracts/directorio-emergencia.schema.json`. A test compares them with
/// the JSON Schema, so the app accepts exactly the files that the CDN checks publish.
abstract final class EmergencyContract {
  static const entryIdPattern = r'^[a-z0-9-]{2,60}$';
  static const phonePattern = r'^\+?[0-9][0-9 ]{1,18}[0-9]$';
  static const filePattern = r'^[a-z0-9-]{2,60}\.json$';
  static const sha256Pattern = r'^[0-9a-f]{64}$';
  static const directoryFields = {'version', 'distrito', 'generadoEn', 'entradas'};
  static const entryFields = {
    'id',
    'tipo',
    'nombre',
    'telefono',
    'ubicacion',
    'direccion',
    'descripcion',
    'fuente',
    'verificadoEn',
  };
  static const requiredEntryFields = {'id', 'tipo', 'nombre', 'fuente', 'verificadoEn'};
  static const sourceFields = {'nombre', 'url'};
  static const locationFields = {'lat', 'lng'};
  static const indexFields = {'version', 'generadoEn', 'distritos'};
  static const indexDistrictFields = {'id', 'archivo', 'version', 'sha256', 'bytes', 'zonas'};
  static const maxEntries = 500;
  static const maxFileBytes = 1048576;
}

/// Kind of entry, with the value of `tipo` in the contract.
enum EmergencyEntryType {
  number('numero'),
  meetingPoint('punto_de_encuentro'),
  healthCenter('centro_de_salud'),
  shelter('albergue');

  const EmergencyEntryType(this.apiValue);

  final String apiValue;

  static EmergencyEntryType? fromApi(String value) {
    for (final type in values) {
      if (type.apiValue == value) return type;
    }
    return null;
  }
}

class EmergencyLocation {
  const EmergencyLocation({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// Who published the entry: an institution or an ally, with its page when it has one.
class EmergencySource {
  const EmergencySource({required this.name, this.url});

  final String name;
  final Uri? url;
}

class EmergencyEntry {
  const EmergencyEntry({
    required this.id,
    required this.type,
    required this.name,
    required this.source,
    required this.verifiedOn,
    this.phone,
    this.location,
    this.address,
    this.description,
  });

  final String id;
  final EmergencyEntryType type;
  final String name;

  /// Institutional number to dial (required for [EmergencyEntryType.number]).
  final String? phone;

  /// Required for every type except [EmergencyEntryType.number].
  final EmergencyLocation? location;
  final String? address;
  final String? description;
  final EmergencySource source;

  /// Last day the curator checked the entry against its source, as a UTC date without time.
  final DateTime verifiedOn;
}

/// Where the copy the neighbor sees comes from.
enum EmergencyDirectoryOrigin {
  /// Last valid copy downloaded from the CDN for the neighbor's zone.
  downloaded,

  /// Copy bundled with the app (national numbers), shown until the first valid download.
  backup,
}

/// Public emergency directory of one district. Institutional information only: never data about
/// neighbors.
class EmergencyDirectory {
  const EmergencyDirectory({
    required this.version,
    required this.district,
    required this.generatedAt,
    required this.entries,
    required this.origin,
  });

  final int version;
  final String district;
  final DateTime generatedAt;
  final List<EmergencyEntry> entries;
  final EmergencyDirectoryOrigin origin;
}

/// One district file of `emergencia/indice.json`.
class EmergencyIndexEntry {
  const EmergencyIndexEntry({
    required this.id,
    required this.file,
    required this.version,
    required this.sha256,
    required this.bytes,
    required this.zones,
  });

  final String id;

  /// Name under `emergencia/`. The contract only allows `[a-z0-9-]` names, so it is safe in a URL.
  final String file;
  final int version;
  final String sha256;
  final int bytes;
  final List<String> zones;
}

class EmergencyIndex {
  const EmergencyIndex({required this.version, required this.generatedAt, required this.districts});

  final int version;
  final DateTime generatedAt;
  final List<EmergencyIndexEntry> districts;

  /// District file that serves [zoneId], or null while the zone has none.
  EmergencyIndexEntry? forZone(String zoneId) {
    final zone = zoneId.toLowerCase();
    for (final district in districts) {
      if (district.zones.any((candidate) => candidate.toLowerCase() == zone)) return district;
    }
    return null;
  }
}

/// Age after which an entry is shown as possibly outdated. It is never hidden.
///
/// Configurable until the team fixes the thresholds with the allies (decision 13.3.6).
class EmergencyStalenessPolicy {
  const EmergencyStalenessPolicy({
    this.defaultMaxAgeDays = 30,
    this.maxAgeDaysByType = const {EmergencyEntryType.number: 180},
  });

  final int defaultMaxAgeDays;
  final Map<EmergencyEntryType, int> maxAgeDaysByType;

  int maxAgeDaysFor(EmergencyEntryType type) => maxAgeDaysByType[type] ?? defaultMaxAgeDays;

  /// Whole days since the verification, counted in UTC like `verificadoEn`.
  bool isPossiblyOutdated(EmergencyEntry entry, DateTime now) {
    final today = now.toUtc();
    final days = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(entry.verifiedOn).inDays;
    return days > maxAgeDaysFor(entry.type);
  }
}

/// Decodes and validates a district file. Throws [FormatException] for anything outside the
/// contract (including invalid UTF-8 or JSON), so the caller keeps its previous valid copy.
EmergencyDirectory decodeEmergencyDirectory(
  List<int> bytes, {
  required EmergencyDirectoryOrigin origin,
}) => parseEmergencyDirectory(jsonDecode(utf8.decode(bytes)), origin: origin);

/// Validates an already decoded district file against the contract.
EmergencyDirectory parseEmergencyDirectory(
  Object? json, {
  required EmergencyDirectoryOrigin origin,
}) {
  final root = _object(
    json,
    'directorio',
    allowed: EmergencyContract.directoryFields,
    required: EmergencyContract.directoryFields,
  );
  final entries = _list(root['entradas'], 'entradas', min: 1, max: EmergencyContract.maxEntries);
  return EmergencyDirectory(
    version: _integer(root['version'], 'version', min: 1),
    district: _text(root['distrito'], 'distrito', min: 2, max: 80),
    generatedAt: _dateTime(root['generadoEn'], 'generadoEn'),
    entries: [for (final (index, entry) in entries.indexed) _entry(entry, 'entradas[$index]')],
    origin: origin,
  );
}

/// Decodes and validates `emergencia/indice.json`.
EmergencyIndex decodeEmergencyIndex(List<int> bytes) =>
    parseEmergencyIndex(jsonDecode(utf8.decode(bytes)));

EmergencyIndex parseEmergencyIndex(Object? json) {
  final root = _object(
    json,
    'indice',
    allowed: EmergencyContract.indexFields,
    required: EmergencyContract.indexFields,
  );
  final districts = _list(root['distritos'], 'distritos', min: 1);
  return EmergencyIndex(
    version: _integer(root['version'], 'version', min: 1),
    generatedAt: _dateTime(root['generadoEn'], 'generadoEn'),
    districts: [
      for (final (index, district) in districts.indexed) _indexEntry(district, 'distritos[$index]'),
    ],
  );
}

final _entryId = RegExp(EmergencyContract.entryIdPattern);
final _phone = RegExp(EmergencyContract.phonePattern);
final _file = RegExp(EmergencyContract.filePattern);
final _sha256 = RegExp(EmergencyContract.sha256Pattern);
final _uuid = RegExp(r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$');
final _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
final _dateTimePattern = RegExp(
  r'^\d{4}-\d{2}-\d{2}[Tt ]\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:[Zz]|[+-]\d{2}:?\d{2})$',
);

EmergencyEntry _entry(Object? json, String where) {
  final map = _object(
    json,
    where,
    allowed: EmergencyContract.entryFields,
    required: EmergencyContract.requiredEntryFields,
  );
  final typeValue = map['tipo'];
  final type = typeValue is String ? EmergencyEntryType.fromApi(typeValue) : null;
  if (type == null) throw FormatException('$where.tipo: tipo desconocido');
  final phone = map.containsKey('telefono')
      ? _text(map['telefono'], '$where.telefono', pattern: _phone)
      : null;
  final location = map.containsKey('ubicacion')
      ? _location(map['ubicacion'], '$where.ubicacion')
      : null;
  if (type == EmergencyEntryType.number && phone == null) {
    throw FormatException('$where: un número necesita telefono');
  }
  if (type != EmergencyEntryType.number && location == null) {
    throw FormatException('$where: necesita ubicacion');
  }
  return EmergencyEntry(
    id: _text(map['id'], '$where.id', pattern: _entryId),
    type: type,
    name: _text(map['nombre'], '$where.nombre', min: 2, max: 120),
    phone: phone,
    location: location,
    address: map.containsKey('direccion')
        ? _text(map['direccion'], '$where.direccion', min: 2, max: 200)
        : null,
    description: map.containsKey('descripcion')
        ? _text(map['descripcion'], '$where.descripcion', min: 2, max: 300)
        : null,
    source: _source(map['fuente'], '$where.fuente'),
    verifiedOn: _calendarDate(map['verificadoEn'], '$where.verificadoEn'),
  );
}

EmergencySource _source(Object? json, String where) {
  final map = _object(
    json,
    where,
    allowed: EmergencyContract.sourceFields,
    required: const {'nombre'},
  );
  return EmergencySource(
    name: _text(map['nombre'], '$where.nombre', min: 2, max: 120),
    url: map.containsKey('url') ? _httpsUrl(map['url'], '$where.url') : null,
  );
}

Uri _httpsUrl(Object? json, String where) {
  final text = _text(json, where);
  final parsed = Uri.tryParse(text);
  if (parsed == null || !text.startsWith('https://') || parsed.host.isEmpty) {
    throw FormatException('$where: se esperaba una dirección https');
  }
  return parsed;
}

EmergencyLocation _location(Object? json, String where) {
  final map = _object(
    json,
    where,
    allowed: EmergencyContract.locationFields,
    required: EmergencyContract.locationFields,
  );
  return EmergencyLocation(
    lat: _number(map['lat'], '$where.lat', min: -90, max: 90),
    lng: _number(map['lng'], '$where.lng', min: -180, max: 180),
  );
}

EmergencyIndexEntry _indexEntry(Object? json, String where) {
  final map = _object(
    json,
    where,
    allowed: EmergencyContract.indexDistrictFields,
    required: EmergencyContract.indexDistrictFields,
  );
  final zones = _list(map['zonas'], '$where.zonas', min: 1);
  return EmergencyIndexEntry(
    id: _text(map['id'], '$where.id', pattern: _entryId),
    file: _text(map['archivo'], '$where.archivo', pattern: _file),
    version: _integer(map['version'], '$where.version', min: 1),
    sha256: _text(map['sha256'], '$where.sha256', pattern: _sha256),
    bytes: _integer(map['bytes'], '$where.bytes', min: 1, max: EmergencyContract.maxFileBytes),
    zones: [
      for (final (index, zone) in zones.indexed)
        _text(zone, '$where.zonas[$index]', pattern: _uuid),
    ],
  );
}

Map<String, Object?> _object(
  Object? json,
  String where, {
  required Set<String> allowed,
  Set<String> required = const {},
}) {
  if (json is! Map<String, Object?>) throw FormatException('$where: se esperaba un objeto');
  for (final field in json.keys) {
    if (!allowed.contains(field)) throw FormatException('$where: campo no previsto $field');
  }
  for (final field in required) {
    if (!json.containsKey(field)) throw FormatException('$where: falta $field');
  }
  return json;
}

List<Object?> _list(Object? json, String where, {required int min, int? max}) {
  if (json is! List<Object?>) throw FormatException('$where: se esperaba una lista');
  if (json.length < min || (max != null && json.length > max)) {
    throw FormatException('$where: cantidad fuera de rango');
  }
  return json;
}

/// Lengths count Unicode code points, like JSON Schema.
String _text(Object? json, String where, {int min = 1, int max = 2000, RegExp? pattern}) {
  if (json is! String) throw FormatException('$where: se esperaba texto');
  final length = json.runes.length;
  if (length < min || length > max) throw FormatException('$where: longitud fuera de rango');
  if (pattern != null && !pattern.hasMatch(json)) throw FormatException('$where: formato inválido');
  return json;
}

int _integer(Object? json, String where, {required int min, int? max}) {
  if (json is! int) throw FormatException('$where: se esperaba un entero');
  if (json < min || (max != null && json > max)) throw FormatException('$where: fuera de rango');
  return json;
}

double _number(Object? json, String where, {required double min, required double max}) {
  if (json is! num || json < min || json > max) {
    throw FormatException('$where: se esperaba un número entre $min y $max');
  }
  return json.toDouble();
}

DateTime _dateTime(Object? json, String where) {
  final text = _text(json, where);
  final parsed = _dateTimePattern.hasMatch(text) ? DateTime.tryParse(text) : null;
  if (parsed == null) throw FormatException('$where: se esperaba fecha y hora');
  return parsed.toUtc();
}

DateTime _calendarDate(Object? json, String where) {
  final match = _date.firstMatch(_text(json, where));
  if (match == null) throw FormatException('$where: se esperaba una fecha AAAA-MM-DD');
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    throw FormatException('$where: la fecha no existe');
  }
  return date;
}
