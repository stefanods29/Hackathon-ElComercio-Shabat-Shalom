import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/content/public_content.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';

enum PublicEmergencyKind { phone, meetingPoint, healthCenter, shelter }

class PublicEmergencyEntry {
  const PublicEmergencyEntry({
    required this.id,
    required this.kind,
    required this.label,
    required this.sourceName,
    required this.verifiedAt,
    this.sourceUrl,
    this.number,
    this.location,
    this.address,
    this.description,
  });
  final String id;
  final PublicEmergencyKind kind;
  final String label;
  final String sourceName;
  final Uri? sourceUrl;
  final DateTime verifiedAt;
  final String? number;
  final GeoPoint? location;
  final String? address;
  final String? description;
  String get sourceCitation => sourceUrl == null ? sourceName : '$sourceName · $sourceUrl';
  bool staleAt(DateTime now) =>
      now.difference(verifiedAt).inDays > (kind == PublicEmergencyKind.phone ? 180 : 30);
}

class PublicEmergencyDirectory {
  const PublicEmergencyDirectory({
    required this.entries,
    required this.district,
    required this.version,
    required this.generatedAt,
    this.bundled = false,
  });
  final List<PublicEmergencyEntry> entries;
  final String district;
  final int version;
  final DateTime generatedAt;
  final bool bundled;

  /// Mirrors A2's contracts/directorio-emergencia.schema.json; version is content revision.
  factory PublicEmergencyDirectory.parse(Object? json) {
    if (json is! Map ||
        json.keys.any(
          (key) => !const ['version', 'distrito', 'generadoEn', 'entradas'].contains(key),
        )) {
      throw const FormatException('Invalid emergency directory');
    }
    final version = json['version'];
    final district = _text(json['distrito'], 2, 80);
    final generated = json['generadoEn'];
    if (version is! int ||
        version < 1 ||
        generated is! String ||
        !generated.contains('T') ||
        DateTime.tryParse(generated) == null ||
        json['entradas'] is! List) {
      throw const FormatException('Invalid directory metadata');
    }
    final rows = json['entradas'] as List;
    if (rows.isEmpty || rows.length > 500) throw const FormatException('Invalid entry count');
    final ids = <String>{};
    final entries = rows
        .map((value) {
          if (value is! Map ||
              value.keys.any(
                (key) => !const [
                  'id',
                  'tipo',
                  'nombre',
                  'telefono',
                  'ubicacion',
                  'direccion',
                  'descripcion',
                  'fuente',
                  'verificadoEn',
                ].contains(key),
              )) {
            throw const FormatException('Invalid emergency entry');
          }
          final id = _text(value['id'], 2, 60);
          if (!RegExp(r'^[a-z0-9-]{2,60}$').hasMatch(id) || !ids.add(id))
            throw const FormatException('Invalid entry id');
          final label = _text(value['nombre'], 2, 120);
          final source = value['fuente'];
          if (source is! Map || source.keys.any((key) => !const ['nombre', 'url'].contains(key)))
            throw const FormatException('Invalid source');
          final sourceName = _text(source['nombre'], 2, 120);
          final sourceUrl = source['url'] == null
              ? null
              : Uri.tryParse(_text(source['url'], 1, 2048));
          if (source['url'] != null &&
              (sourceUrl == null || sourceUrl.scheme != 'https' || sourceUrl.host.isEmpty))
            throw const FormatException('Invalid source URL');
          final rawDate = value['verificadoEn'];
          if (rawDate is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawDate))
            throw const FormatException('Invalid verification date');
          final date = DateTime.tryParse(rawDate);
          if (date == null || date.toIso8601String().substring(0, 10) != rawDate)
            throw const FormatException('Invalid verification date');
          final kind = switch (value['tipo']) {
            'numero' => PublicEmergencyKind.phone,
            'punto_de_encuentro' => PublicEmergencyKind.meetingPoint,
            'centro_de_salud' => PublicEmergencyKind.healthCenter,
            'albergue' => PublicEmergencyKind.shelter,
            _ => throw const FormatException('Unknown entry type'),
          };
          final number = value['telefono'] == null ? null : _text(value['telefono'], 3, 20);
          if (number != null && !RegExp(r'^\+?[0-9][0-9 ]{1,18}[0-9]$').hasMatch(number))
            throw const FormatException('Invalid institutional phone');
          GeoPoint? point;
          if (value['ubicacion'] != null) {
            final location = value['ubicacion'];
            if (location is! Map || location.keys.any((key) => !const ['lat', 'lng'].contains(key)))
              throw const FormatException('Invalid location');
            final lat = location['lat'];
            final lng = location['lng'];
            if (lat is! num ||
                lng is! num ||
                !lat.isFinite ||
                !lng.isFinite ||
                lat < -90 ||
                lat > 90 ||
                lng < -180 ||
                lng > 180)
              throw const FormatException('Invalid public point');
            point = GeoPoint(lat.toDouble(), lng.toDouble()).approximate();
          }
          if (kind == PublicEmergencyKind.phone && number == null ||
              kind != PublicEmergencyKind.phone && point == null)
            throw const FormatException('Incomplete entry');
          return PublicEmergencyEntry(
            id: id,
            kind: kind,
            label: label,
            sourceName: sourceName,
            sourceUrl: sourceUrl,
            verifiedAt: date,
            number: number,
            location: point,
            address: value['direccion'] == null ? null : _text(value['direccion'], 2, 200),
            description: value['descripcion'] == null ? null : _text(value['descripcion'], 2, 300),
          );
        })
        .toList(growable: false);
    return PublicEmergencyDirectory(
      entries: entries,
      district: district,
      version: version,
      generatedAt: DateTime.parse(generated),
      bundled: district == 'Respaldo nacional',
    );
  }
  static String _text(Object? value, int min, int max) {
    if (value is! String || value.trim().length < min || value.length > max)
      throw const FormatException('Invalid public text');
    return value.trim();
  }
}

/// A2 may inject the verified district URL; no guessed endpoint is used by default.
final emergencyDirectoryUrlProvider = Provider<Uri?>((ref) {
  const url = String.fromEnvironment('PUBLIC_EMERGENCY_DIRECTORY_URL');
  return url.isEmpty ? null : Uri.tryParse(url);
});
final publicEmergencyDirectoryProvider = StreamProvider<PublicEmergencyDirectory>((ref) {
  final uri = ref.watch(emergencyDirectoryUrlProvider);
  return watchPublicContent(
    source: ref.watch(publicContentSourceProvider),
    key: 'emergency.v1.${uri?.toString() ?? "bundled"}',
    asset: 'assets/public/emergency_directory.json',
    uri: uri,
    parse: PublicEmergencyDirectory.parse,
  );
});
