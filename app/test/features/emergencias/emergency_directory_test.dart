import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/features/emergencias/domain/emergency_directory.dart';

const pilotZone = '01970000-0000-7000-8000-000000000001';

Map<String, Object?> readJson(String file) =>
    jsonDecode(File(file).readAsStringSync()) as Map<String, Object?>;

Map<String, Object?> obj(Object? value) => value! as Map<String, Object?>;

Set<Object?> listed(Object? value) => (value! as List<Object?>).toSet();

Map<String, Object?> number([Map<String, Object?> changes = const {}]) => {
  'id': 'bomberos',
  'tipo': 'numero',
  'nombre': 'Bomberos',
  'telefono': '116',
  'fuente': {'nombre': 'Fuente oficial'},
  'verificadoEn': '2026-11-07',
  ...changes,
};

Map<String, Object?> district(List<Object?> entries) => {
  'version': 1,
  'distrito': 'Prueba',
  'generadoEn': '2026-11-07T12:00:00Z',
  'entradas': entries,
};

EmergencyDirectory parse(Object? json) =>
    parseEmergencyDirectory(json, origin: EmergencyDirectoryOrigin.downloaded);

void main() {
  group('contrato del directorio de emergencia', () {
    final schema = readJson('../contracts/directorio-emergencia.schema.json');
    final defs = obj(schema[r'$defs']);

    test('el validador de la app usa los campos, tipos y patrones del esquema', () {
      final entry = obj(defs['entrada']);
      final entryProperties = obj(entry['properties']);
      expect(obj(schema['properties']).keys.toSet(), EmergencyContract.directoryFields);
      expect(listed(schema['required']), EmergencyContract.directoryFields);
      expect(obj(obj(schema['properties'])['entradas'])['maxItems'], EmergencyContract.maxEntries);
      expect(entryProperties.keys.toSet(), EmergencyContract.entryFields);
      expect(listed(entry['required']), EmergencyContract.requiredEntryFields);
      expect(
        obj(entryProperties['tipo'])['enum'],
        EmergencyEntryType.values.map((type) => type.apiValue).toList(),
      );
      expect(obj(entryProperties['id'])['pattern'], EmergencyContract.entryIdPattern);
      expect(obj(entryProperties['telefono'])['pattern'], EmergencyContract.phonePattern);
      expect(
        obj(obj(entryProperties['fuente'])['properties']).keys.toSet(),
        EmergencyContract.sourceFields,
      );
      expect(
        obj(obj(entryProperties['ubicacion'])['properties']).keys.toSet(),
        EmergencyContract.locationFields,
      );

      final index = obj(defs['indice']);
      final districtProperties = obj(
        obj(obj(obj(index['properties'])['distritos'])['items'])['properties'],
      );
      expect(obj(index['properties']).keys.toSet(), EmergencyContract.indexFields);
      expect(districtProperties.keys.toSet(), EmergencyContract.indexDistrictFields);
      expect(obj(districtProperties['archivo'])['pattern'], EmergencyContract.filePattern);
      expect(obj(districtProperties['sha256'])['pattern'], EmergencyContract.sha256Pattern);
      expect(obj(districtProperties['bytes'])['maximum'], EmergencyContract.maxFileBytes);
    });

    test('los archivos publicados en la CDN pasan el validador y su hash', () {
      final index = parseEmergencyIndex(readJson('../infra/cdn/publico/emergencia/indice.json'));
      expect(index.forZone(pilotZone)?.file, 'lince-demo.json');
      for (final entry in index.districts) {
        final bytes = File('../infra/cdn/publico/emergencia/${entry.file}').readAsBytesSync();
        expect(bytes.length, entry.bytes);
        expect(sha256.convert(bytes).toString(), entry.sha256);
        final published = decodeEmergencyDirectory(
          bytes,
          origin: EmergencyDirectoryOrigin.downloaded,
        );
        expect(published.version, entry.version);
        for (final item in published.entries) {
          expect(item.source.name, isNotEmpty);
        }
      }
    });

    test('la copia de respaldo trae 116, 105 y 106 con su fuente y su fecha', () {
      final backup = parseEmergencyDirectory(
        readJson('assets/emergencia/respaldo.json'),
        origin: EmergencyDirectoryOrigin.backup,
      );
      expect(backup.entries.map((entry) => entry.phone).toList(), ['116', '105', '106']);
      for (final entry in backup.entries) {
        expect(entry.type, EmergencyEntryType.number);
        expect(entry.source.name, isNotEmpty);
        expect(entry.source.url?.scheme, 'https');
        expect(entry.verifiedOn, DateTime.utc(2026, 11, 7));
      }
    });

    test('acepta un punto de encuentro con ubicación', () {
      final meetingPoint = {
        'id': 'parque',
        'tipo': 'punto_de_encuentro',
        'nombre': 'Parque de prueba',
        'ubicacion': {'lat': -12.085, 'lng': -77.035},
        'direccion': 'Av. de prueba 123',
        'fuente': {'nombre': 'Municipalidad de prueba', 'url': 'https://www.gob.pe/'},
        'verificadoEn': '2026-11-07',
      };
      final parsed = parse(district([meetingPoint, number()]));
      expect(parsed.entries.first.type, EmergencyEntryType.meetingPoint);
      expect(parsed.entries.first.location?.lat, -12.085);
      expect(parsed.entries.first.address, 'Av. de prueba 123');
    });

    test('rechaza lo que el contrato no permite', () {
      final rejects = throwsA(isA<FormatException>());
      expect(() => parse(district([number()])), returnsNormally);
      expect(() => parse(district([Map.of(number())..remove('fuente')])), rejects);
      expect(() => parse(district([Map.of(number())..remove('telefono')])), rejects);
      expect(() => parse(district([Map.of(number())..remove('verificadoEn')])), rejects);
      expect(
        () => parse(
          district([
            number({'telefonoVecino': '999999999'}),
          ]),
        ),
        rejects,
      );
      expect(
        () => parse({
          ...district([number()]),
          'zona': pilotZone,
        }),
        rejects,
      );
      expect(() => parse(district([])), rejects);
      expect(
        () => parse(
          district([
            number({'tipo': 'refugio'}),
          ]),
        ),
        rejects,
      );
      expect(
        () => parse(
          district([
            number({'tipo': 'albergue'}),
          ]),
        ),
        rejects,
      );
      expect(
        () => parse(
          district([
            number({'verificadoEn': '2026-02-30'}),
          ]),
        ),
        rejects,
      );
      expect(
        () => parse(
          district([
            number({'telefono': '11a'}),
          ]),
        ),
        rejects,
      );
      expect(
        () => parse(
          district([
            number({
              'fuente': {'nombre': 'Fuente', 'url': 'http://inseguro.example'},
            }),
          ]),
        ),
        rejects,
      );
      expect(
        () => parse({
          ...district([number()]),
          'version': 0,
        }),
        rejects,
      );
      expect(
        () => decodeEmergencyDirectory(
          utf8.encode('{no es json'),
          origin: EmergencyDirectoryOrigin.downloaded,
        ),
        rejects,
      );
    });

    test('un índice con un nombre de archivo fuera del patrón no se acepta', () {
      final index = readJson('../infra/cdn/publico/emergencia/indice.json');
      final districts = (index['distritos']! as List<Object?>)
          .map((entry) => {...obj(entry), 'archivo': '../secreto.json'})
          .toList();
      expect(
        () => parseEmergencyIndex({...index, 'distritos': districts}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('antigüedad de los datos', () {
    const policy = EmergencyStalenessPolicy();
    final verified = DateTime.utc(2026, 11, 7);

    EmergencyEntry entry(EmergencyEntryType type) => EmergencyEntry(
      id: 'dato',
      type: type,
      name: 'Dato',
      source: const EmergencySource(name: 'Fuente'),
      verifiedOn: verified,
      phone: type == EmergencyEntryType.number ? '116' : null,
      location: type == EmergencyEntryType.number
          ? null
          : const EmergencyLocation(lat: -12.085, lng: -77.035),
    );

    test('un punto de encuentro verificado hace 45 días se marca, sin ocultarse', () {
      final now = DateTime.utc(2026, 12, 22, 15);
      expect(policy.isPossiblyOutdated(entry(EmergencyEntryType.meetingPoint), now), isTrue);
    });

    test('un número verificado hace 45 días sigue vigente: su umbral es de 180', () {
      final now = DateTime.utc(2026, 12, 22, 15);
      expect(policy.isPossiblyOutdated(entry(EmergencyEntryType.number), now), isFalse);
    });

    test('el umbral se supera desde el día 31', () {
      expect(
        policy.isPossiblyOutdated(entry(EmergencyEntryType.shelter), DateTime.utc(2026, 12, 7, 23)),
        isFalse,
      );
      expect(
        policy.isPossiblyOutdated(entry(EmergencyEntryType.shelter), DateTime.utc(2026, 12, 8)),
        isTrue,
      );
    });

    test('los umbrales se pueden configurar por tipo', () {
      const strict = EmergencyStalenessPolicy(
        defaultMaxAgeDays: 7,
        maxAgeDaysByType: {EmergencyEntryType.healthCenter: 90},
      );
      final now = DateTime.utc(2026, 11, 20);
      expect(strict.isPossiblyOutdated(entry(EmergencyEntryType.meetingPoint), now), isTrue);
      expect(strict.isPossiblyOutdated(entry(EmergencyEntryType.healthCenter), now), isFalse);
    });
  });
}
