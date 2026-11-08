import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:powersync/powersync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/features/directorio/data/in_memory_service_directory_repository.dart';
import 'package:vecinal/features/directorio/data/powersync_service_directory_repository.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/features/reputacion/data/in_memory_reputation_repository.dart';
import 'package:vecinal/features/reputacion/data/powersync_reputation_repository.dart';
import 'package:vecinal/features/reputacion/data/providers.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart';

const me = 'vecino';
const zone = 'zona-piloto';
const otherZone = 'zona-vecina';

/// Simulates a row downloaded by PowerSync: it goes straight to the synced table's storage,
/// without creating an upload in `ps_crud`.
Future<void> downloaded(PowerSyncDatabase db, String table, Map<String, Object?> row) => db.execute(
  'INSERT INTO ps_data__$table (id, data) VALUES (?, ?)',
  [row['id'], jsonEncode(row)],
);

Map<String, Object?> serviceRow(
  String id, {
  String provider = 'proveedor',
  String zoneId = zone,
  String title = 'Gasfitero a domicilio',
  int endorsements = 0,
  double score = 0,
  int version = 1,
}) => {
  'id': id,
  'proveedor_id': provider,
  'zona_id': zoneId,
  'categoria_id': 'gasfiteria',
  'titulo': title,
  'descripcion': null,
  'lat': -12.086,
  'lng': -77.035,
  'radio_cobertura_m': 2000,
  'disponible_en_emergencia': 1,
  'atributos': '{"horario":"tardes"}',
  'total_resenas': 2,
  'promedio': 4.5,
  'puntaje_ranking': score,
  'vistos_buenos_de_la_zona': endorsements,
  'version': version,
  'actualizado_en': '2026-11-07T12:00:00Z',
};

void main() {
  late Directory directory;
  late LocalSyncDatabase local;
  late PowerSyncDatabase db;
  late PowerSyncServiceDirectoryRepository services;
  late PowerSyncReputationRepository reputation;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('vecinal-directorio-');
    local = await LocalSyncDatabase.open(
      path: '${directory.path}/directorio.db',
      store: InMemorySecureStore(),
      accountId: me,
    );
    db = local.database;
    services = PowerSyncServiceDirectoryRepository(db, neighborId: me, zoneId: zone);
    reputation = PowerSyncReputationRepository(db, neighborId: me, zoneId: zone);
  });

  tearDown(() async {
    await local.close();
    await directory.delete(recursive: true);
  });

  group('lecturas sin conexión', () {
    test('el directorio descargado se lee sin red y solo con lo de la zona', () async {
      await downloaded(db, 'categorias', {
        'id': 'clases',
        'nombre': 'Clases',
        'icono': 'school',
        'util_en_emergencia': 0,
        'orden': 2,
      });
      await downloaded(db, 'categorias', {
        'id': 'gasfiteria',
        'nombre': 'Gasfitería',
        'icono': 'plumbing',
        'util_en_emergencia': 1,
        'orden': 1,
      });
      await downloaded(db, 'servicios', serviceRow('s1', score: 4.0));
      await downloaded(db, 'servicios', serviceRow('s2', endorsements: 3, title: 'Gásfiter'));
      await downloaded(db, 'servicios', serviceRow('s3', zoneId: otherZone));
      await downloaded(db, 'proveedores', {
        'id': 'proveedor',
        'nombre_publico': 'Don Luis',
        'descripcion': null,
        'actualizado_en': '2026-11-07T12:00:00Z',
      });

      final categories = await services.watchCategories().first;
      expect(categories.map((c) => c.id), ['gasfiteria', 'clases']);
      expect(categories.first.usefulInEmergency, isTrue);

      final list = await services.watchServices().first;
      expect(list.map((s) => s.id), ['s2', 's1']);
      expect(list.last.attributes, {'horario': 'tardes'});
      expect(list.last.location, const GeoPoint(-12.086, -77.035));
      expect(list.every((s) => s.submissionStatus == SubmissionStatus.sent), isTrue);

      final search = await services.watchServices(const ServiceQuery(text: 'gasfiter')).first;
      expect(search.map((s) => s.id).toSet(), {'s1', 's2'});
      expect((await services.watchProvider('proveedor').first)!.publicName, 'Don Luis');
      expect(await services.watchService('s3').first, isNull);
    });

    test('las reseñas publicadas traen sus fotos en orden y no dicen quién las escribió', () async {
      await downloaded(db, 'resenas', {
        'id': 'r1',
        'servicio_id': 's1',
        'calificacion': 5,
        'comentario': 'Muy bien',
        'publicada_en': '2026-11-06T10:00:00Z',
      });
      await downloaded(db, 'resenas', {
        'id': 'r2',
        'servicio_id': 's1',
        'calificacion': 3,
        'comentario': null,
        'publicada_en': '2026-11-07T10:00:00Z',
      });
      for (final (id, order) in [('f2', 1), ('f1', 0)]) {
        await downloaded(db, 'fotos_resena', {
          'id': id,
          'resena_id': 'r1',
          'archivo_id': 'archivo-$id',
          'orden': order,
          'ancho': 320,
          'alto': 240,
          'blurhash': null,
        });
      }
      await downloaded(db, 'mis_resenas', {
        'id': 'r2',
        'servicio_id': 's1',
        'calificacion': 3,
        'comentario': null,
        'estado': 'publicada',
        'motivo_estado': null,
        'creado_en': '2026-11-07T09:00:00Z',
        'actualizado_en': '2026-11-07T10:00:00Z',
      });

      final reviews = await reputation.watchPublishedReviews('s1').first;
      expect(reviews.map((r) => r.id), ['r2', 'r1']);
      expect(reviews.first.isMine, isTrue);
      expect(reviews.last.photos.map((p) => p.id), ['f1', 'f2']);
      expect(reviews.last.photos.first.fileId, 'archivo-f1');
    });
  });

  group('escrituras optimistas', () {
    test(
      'publicar un servicio se ve al instante y solo la API recibe la ubicación exacta',
      () async {
        await services.publishService(
          const ServiceDraft(
            categoryId: 'gasfiteria',
            title: 'Arreglo fugas',
            location: GeoPoint(-12.085678, -77.034567),
          ),
        );
        final list = await services.watchServices().first;
        expect(list.single.submissionStatus, SubmissionStatus.savedOnPhone);
        expect(list.single.location, const GeoPoint(-12.086, -77.035));
        expect(list.single.providerId, me);

        final upload = (await db.getNextCrudTransaction())!;
        final body = jsonDecode(upload.crud.single.opData!['cuerpo'] as String) as Map;
        expect(upload.crud.single.opData!['tipo'], 'publishService');
        expect(body['ubicacion'], {'lat': -12.085678, 'lng': -77.034567});
        expect(body['muestraUbicacionExacta'], isFalse);
      },
    );

    test('solo el dueño edita o retira, y retirar lo oculta al instante', () async {
      await downloaded(db, 'servicios', serviceRow('mio', provider: me, title: 'Antes'));
      await downloaded(db, 'servicios', serviceRow('ajeno'));

      await expectLater(
        services.updateService(
          serviceId: 'ajeno',
          seenVersion: 1,
          changes: const ServiceDraft(
            categoryId: 'gasfiteria',
            title: 'X',
            location: GeoPoint(0, 0),
          ),
        ),
        throwsA(isA<LocalValidationError>()),
      );
      await services.updateService(
        serviceId: 'mio',
        seenVersion: 1,
        changes: const ServiceDraft(
          categoryId: 'gasfiteria',
          title: 'Después',
          location: GeoPoint(-12.0861, -77.0352),
        ),
      );
      final edited = (await services.watchService('mio').first)!;
      expect(edited.title, 'Después');
      expect(edited.version, 2);
      expect(edited.reviewCount, 2);
      expect(edited.submissionStatus, SubmissionStatus.savedOnPhone);

      await services.withdrawService('mio');
      expect((await services.watchServices().first).map((s) => s.id), ['ajeno']);
    });

    test('nadie se reseña a sí mismo ni reseña dos veces el mismo servicio', () async {
      await downloaded(db, 'servicios', serviceRow('mio', provider: me));
      await downloaded(db, 'servicios', serviceRow('ajeno'));
      await expectLater(
        reputation.writeReview(const NewReview(serviceId: 'mio', rating: 5)),
        throwsA(isA<LocalValidationError>()),
      );
      await reputation.writeReview(const NewReview(serviceId: 'ajeno', rating: 4, comment: 'Bien'));
      final mine = (await reputation.watchMyReviews().first).single;
      expect(mine.status, ReviewStatus.inReview);
      expect(mine.submissionStatus, SubmissionStatus.savedOnPhone);
      await expectLater(
        reputation.writeReview(const NewReview(serviceId: 'ajeno', rating: 2)),
        throwsA(isA<LocalValidationError>()),
      );
    });

    test('el Visto Bueno descargado y el pendiente se combinan, y retirarlo lo quita', () async {
      await downloaded(db, 'servicios', serviceRow('s1'));
      await downloaded(db, 'servicios', serviceRow('s2'));
      await downloaded(db, 'mis_vistos_buenos', {
        'id': 'v1',
        'servicio_id': 's1',
        'creado_en': '2026-11-07T12:00:00Z',
      });
      await expectLater(reputation.giveEndorsement('s1'), throwsA(isA<LocalValidationError>()));
      await reputation.giveEndorsement('s2');
      expect((await reputation.watchMyEndorsements().first).map((e) => e.serviceId).toSet(), {
        's1',
        's2',
      });
      await reputation.withdrawEndorsement('s1');
      expect((await reputation.watchMyEndorsements().first).map((e) => e.serviceId), ['s2']);
    });
  });

  test('el conector envía cada acción con su método, su ruta y su clave, y un rechazo no bloquea '
      'la cola', () async {
    await downloaded(db, 'servicios', serviceRow('mio', provider: me));
    await downloaded(db, 'servicios', serviceRow('ajeno'));
    await services.publishService(
      const ServiceDraft(
        categoryId: 'gasfiteria',
        title: 'Clases de gasfitería',
        location: GeoPoint(-12.08, -77.03),
      ),
    );
    await reputation.writeReview(const NewReview(serviceId: 'ajeno', rating: 5));
    await reputation.giveEndorsement('ajeno');
    await reputation.report(
      const NewReport(
        content: ReportedContent.service,
        contentId: 'ajeno',
        reason: ReportReason.spam,
      ),
    );
    await services.withdrawService('mio');

    final requests = <RequestOptions>[];
    final api = createApiClient(
      const AppEnvironment(apiBaseUrl: 'https://api.example.test', powersyncUrl: ''),
      getToken: () async => 'access-token',
    );
    addTearDown(api.close);
    api.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          final rejected = request.path == '/v1/resenas';
          handler.resolve(
            Response(
              requestOptions: request,
              statusCode: rejected ? 409 : (request.method == 'DELETE' ? 204 : 200),
              data: rejected
                  ? {'status': 409, 'title': 'Conflicto', 'codigo': 'resena_duplicada'}
                  : {},
            ),
          );
        },
      ),
    );
    final connector = VecinalConnector(api);
    for (var i = 0; i < 10 && await db.getNextCrudTransaction() != null; i++) {
      await connector.uploadData(db);
    }
    expect(await db.getNextCrudTransaction(), isNull);

    expect(requests.map((r) => '${r.method} ${r.path}'), [
      'POST /v1/servicios',
      'POST /v1/resenas',
      'POST /v1/servicios/ajeno/visto-bueno',
      'POST /v1/denuncias',
      'DELETE /v1/servicios/mio',
    ]);
    final sent = await db.getAll('SELECT * FROM envios ORDER BY creado_en, id');
    for (final (request, row) in [for (var i = 0; i < 5; i++) (requests[i], sent[i])]) {
      expect(request.headers['Idempotency-Key'], row['clave_idempotencia']);
      expect(row['optimista'], isNull);
    }
    expect(requests[2].data, isNull);
    expect(requests[4].data, isNull);
    expect(jsonDecode(requests[3].data as String), containsPair('motivo', 'spam'));

    final review = sent.singleWhere((row) => row['tipo'] == 'writeReview');
    expect(review['estado'], SubmissionStatus.couldNotComplete.name);
    expect(review['motivo_codigo'], 'resena_duplicada');
    expect(sent.where((row) => row['tipo'] != 'writeReview').map((row) => row['estado']).toSet(), {
      SubmissionStatus.sent.name,
    });
    expect(await reputation.watchMyReviews().first, isEmpty);
  });

  group('proveedores de Riverpod', () {
    Future<ProviderContainer> container({required bool practice}) async {
      SharedPreferences.setMockInitialValues({'practiceMode': practice});
      final container = ProviderContainer.test(
        overrides: [
          syncedServiceDirectoryRepositoryProvider.overrideWithValue(services),
          syncedReputationRepositoryProvider.overrideWithValue(reputation),
        ],
      );
      await container.read(practiceModeProvider.future);
      return container;
    }

    test('las pantallas reciben los repositorios reales de la cuenta', () async {
      final scope = await container(practice: false);
      expect(scope.read(serviceDirectoryRepositoryProvider), same(services));
      expect(scope.read(reputationRepositoryProvider), same(reputation));
    });

    test('en modo práctica nada llega a los repositorios reales', () async {
      final scope = await container(practice: true);
      expect(
        scope.read(serviceDirectoryRepositoryProvider),
        isA<InMemoryServiceDirectoryRepository>(),
      );
      expect(scope.read(reputationRepositoryProvider), isA<InMemoryReputationRepository>());
    });
  });
}
