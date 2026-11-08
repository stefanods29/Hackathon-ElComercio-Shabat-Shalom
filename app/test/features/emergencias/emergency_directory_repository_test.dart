import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/cdn_client.dart';
import 'package:vecinal/features/emergencias/data/emergency_directory_repository.dart';
import 'package:vecinal/features/emergencias/data/emergency_directory_store.dart';
import 'package:vecinal/features/emergencias/domain/emergency_directory.dart';

const pilotZone = '01970000-0000-7000-8000-000000000001';
const otherZone = '01970000-0000-7000-8000-000000000002';

/// The real CDN client with a last interceptor that serves files by path and records what would
/// be sent.
class FakeCdn {
  FakeCdn() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          if (offline) {
            handler.reject(
              DioException(requestOptions: request, type: DioExceptionType.connectionError),
            );
            return;
          }
          final file = files[request.path];
          handler.resolve(
            Response<List<int>>(
              requestOptions: request,
              statusCode: file == null ? 404 : 200,
              data: file ?? <int>[],
            ),
          );
        },
      ),
    );
  }

  final dio = createCdnClient(
    const AppEnvironment(
      apiBaseUrl: 'https://api.example.test',
      powersyncUrl: '',
      cdnBaseUrl: 'https://cdn.example.test',
    ),
  );
  final files = <String, List<int>>{};
  final requests = <RequestOptions>[];
  bool offline = false;

  /// Publishes [district] for [zone] with a matching index, unless [declaredHash] says otherwise.
  void publish(
    List<int> district, {
    String zone = pilotZone,
    int version = 1,
    String? declaredHash,
  }) {
    files['/emergencia/lince-demo.json'] = district;
    files['/emergencia/indice.json'] = utf8.encode(
      jsonEncode({
        'version': 1,
        'generadoEn': '2026-11-07T12:00:00Z',
        'distritos': [
          {
            'id': 'lince-demo',
            'archivo': 'lince-demo.json',
            'version': version,
            'sha256': declaredHash ?? sha256.convert(district).toString(),
            'bytes': district.length,
            'zonas': [zone],
          },
        ],
      }),
    );
  }

  List<String> get paths => [for (final request in requests) request.path];
}

List<int> districtFile({int version = 1, List<Map<String, Object?>>? entries}) => utf8.encode(
  jsonEncode({
    'version': version,
    'distrito': 'Lince (demo)',
    'generadoEn': '2026-11-07T12:00:00Z',
    'entradas':
        entries ??
        [
          {
            'id': 'bomberos',
            'tipo': 'numero',
            'nombre': 'Bomberos',
            'telefono': '116',
            'fuente': {'nombre': 'MTC'},
            'verificadoEn': '2026-11-07',
          },
        ],
  }),
);

void main() {
  late String backupJson;
  late FakeCdn cdn;
  late InMemoryEmergencyDirectoryStore store;
  late DateTime now;
  late EmergencyDirectoryRepository repository;

  setUpAll(() => backupJson = File('assets/emergencia/respaldo.json').readAsStringSync());

  setUp(() {
    cdn = FakeCdn();
    store = InMemoryEmergencyDirectoryStore();
    now = DateTime.utc(2026, 11, 8, 9);
    repository = EmergencyDirectoryRepository(
      cdn: cdn.dio,
      store: store,
      loadBackup: () async => backupJson,
      clock: () => now,
    );
  });

  tearDown(() async {
    await repository.close();
    cdn.dio.close(force: true);
  });

  test('sin descarga previa muestra el respaldo incluido en la app', () async {
    final current = await repository.current();
    expect(current.origin, EmergencyDirectoryOrigin.backup);
    expect(current.entries.map((entry) => entry.phone).toList(), ['116', '105', '106']);
  });

  test('descarga sin token ni identificadores y guarda la copia verificada', () async {
    cdn.publish(districtFile());
    expect(await repository.refresh(zoneId: pilotZone), EmergencyRefreshResult.updated);
    expect(cdn.paths, ['/emergencia/indice.json', '/emergencia/lince-demo.json']);
    for (final request in cdn.requests) {
      final headers = request.headers.keys.map((name) => name.toLowerCase()).toList();
      expect(headers, isNot(contains('authorization')));
      expect(headers, isNot(contains('cookie')));
      expect(request.queryParameters, isEmpty);
      expect(request.uri.toString(), isNot(contains(pilotZone)));
    }
    final current = await repository.current();
    expect(current.origin, EmergencyDirectoryOrigin.downloaded);
    expect(current.district, 'Lince (demo)');
  });

  test('sin cambios no vuelve a descargar el archivo del distrito', () async {
    cdn.publish(districtFile());
    await repository.refresh(zoneId: pilotZone);
    cdn.requests.clear();
    expect(
      await repository.refresh(zoneId: pilotZone, force: true),
      EmergencyRefreshResult.unchanged,
    );
    expect(cdn.paths, ['/emergencia/indice.json']);
  });

  test('revisa la CDN como máximo una vez al día por zona', () async {
    cdn.publish(districtFile());
    await repository.refresh(zoneId: pilotZone);
    cdn.requests.clear();
    now = now.add(const Duration(hours: 23));
    expect(await repository.refresh(zoneId: pilotZone), EmergencyRefreshResult.skipped);
    expect(cdn.requests, isEmpty);
    now = now.add(const Duration(hours: 2));
    expect(await repository.refresh(zoneId: pilotZone), EmergencyRefreshResult.unchanged);
  });

  test('una descarga corrupta conserva la copia anterior y se reintenta después', () async {
    cdn.publish(districtFile());
    await repository.refresh(zoneId: pilotZone);
    final next = districtFile(version: 2);
    cdn.publish(
      next,
      version: 2,
      declaredHash: sha256.convert(districtFile(version: 3)).toString(),
    );
    now = now.add(const Duration(hours: 25));
    expect(await repository.refresh(zoneId: pilotZone), EmergencyRefreshResult.corrupted);
    expect((await repository.current()).version, 1);

    cdn.publish(next, version: 2);
    now = now.add(const Duration(minutes: 1));
    expect(await repository.refresh(zoneId: pilotZone), EmergencyRefreshResult.updated);
    expect((await repository.current()).version, 2);
  });

  test('un archivo con el hash correcto pero fuera del contrato no se guarda', () async {
    cdn.publish(
      districtFile(
        entries: [
          {
            'id': 'sin-fuente',
            'tipo': 'numero',
            'nombre': 'Sin fuente',
            'telefono': '116',
            'verificadoEn': '2026-11-07',
          },
        ],
      ),
    );
    expect(await repository.refresh(zoneId: pilotZone), EmergencyRefreshResult.corrupted);
    expect((await repository.current()).origin, EmergencyDirectoryOrigin.backup);
  });

  test('un índice que no cumple el contrato no reemplaza nada', () async {
    cdn.publish(districtFile());
    await repository.refresh(zoneId: pilotZone);
    cdn.files['/emergencia/indice.json'] = utf8.encode('{"version": 1}');
    expect(
      await repository.refresh(zoneId: pilotZone, force: true),
      EmergencyRefreshResult.corrupted,
    );
    expect((await repository.current()).origin, EmergencyDirectoryOrigin.downloaded);
  });

  test('sin conexión conserva la copia y no cuenta como revisión', () async {
    cdn.publish(districtFile());
    await repository.refresh(zoneId: pilotZone);
    cdn.offline = true;
    now = now.add(const Duration(days: 2));
    expect(await repository.refresh(zoneId: pilotZone), EmergencyRefreshResult.failed);
    expect((await repository.current()).origin, EmergencyDirectoryOrigin.downloaded);
    cdn.offline = false;
    expect(await repository.refresh(zoneId: pilotZone), EmergencyRefreshResult.unchanged);
  });

  test('una zona sin directorio vuelve al respaldo nacional', () async {
    cdn.publish(districtFile());
    await repository.refresh(zoneId: pilotZone);
    expect(await repository.refresh(zoneId: otherZone), EmergencyRefreshResult.noDirectoryForZone);
    expect((await repository.current()).origin, EmergencyDirectoryOrigin.backup);
  });

  test('watch entrega la copia nueva después de una descarga', () async {
    cdn.publish(districtFile());
    final origins = repository.watch().take(2).map((directory) => directory.origin).toList();
    await Future<void>.delayed(Duration.zero);
    await repository.refresh(zoneId: pilotZone);
    expect(await origins, [EmergencyDirectoryOrigin.backup, EmergencyDirectoryOrigin.downloaded]);
  });

  test('borrar la cuenta olvida la zona de la última revisión y deja la copia pública', () async {
    cdn.publish(districtFile());
    await repository.refresh(zoneId: pilotZone);
    await repository.forgetLastCheck();
    expect(await store.readLastCheck(), isNull);
    expect((await repository.current()).origin, EmergencyDirectoryOrigin.downloaded);
  });

  group('FileEmergencyDirectoryStore', () {
    late Directory temporary;

    setUp(() async => temporary = await Directory.systemTemp.createTemp('emergencia'));
    tearDown(() => temporary.delete(recursive: true));

    test('reemplaza la copia de forma atómica y la vuelve a leer', () async {
      final folder = path.join(temporary.path, 'emergencia');
      final files = FileEmergencyDirectoryStore(folder);
      expect(await files.readDirectory(), isNull);
      await files.saveDirectory(Uint8List.fromList(districtFile()));
      await files.saveDirectory(Uint8List.fromList(districtFile(version: 2)));
      final saved = decodeEmergencyDirectory(
        (await files.readDirectory())!,
        origin: EmergencyDirectoryOrigin.downloaded,
      );
      expect(saved.version, 2);
      expect(
        Directory(folder).listSync().map((entry) => path.basename(entry.path)),
        isNot(contains('directorio.json.tmp')),
      );

      await files.saveLastCheck(EmergencyCheck(zoneId: pilotZone, checkedAt: now));
      expect((await files.readLastCheck())?.zoneId, pilotZone);
      await files.deleteLastCheck();
      expect(await files.readLastCheck(), isNull);
    });

    test('una copia dañada en el disco no tapa los números', () async {
      final files = FileEmergencyDirectoryStore(path.join(temporary.path, 'emergencia'));
      await files.saveDirectory(Uint8List.fromList(utf8.encode('{dañado')));
      final fromDisk = EmergencyDirectoryRepository(
        cdn: cdn.dio,
        store: files,
        loadBackup: () async => backupJson,
      );
      addTearDown(fromDisk.close);
      expect((await fromDisk.current()).origin, EmergencyDirectoryOrigin.backup);
    });
  });
}
