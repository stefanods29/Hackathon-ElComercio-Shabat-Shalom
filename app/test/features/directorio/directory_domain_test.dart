import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/features/directorio/data/in_memory_service_directory_repository.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/domain/search.dart';
import 'package:vecinal/features/directorio/domain/use_cases.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart';

Service service(
  String id, {
  String title = 'Servicio',
  String category = 'gasfiteria',
  bool emergency = false,
  int endorsements = 0,
  double score = 0,
  String zone = 'zona',
  String provider = 'otro',
}) => Service(
  id: id,
  providerId: provider,
  zoneId: zone,
  categoryId: category,
  title: title,
  location: const GeoPoint(-12.086, -77.035),
  availableInEmergency: emergency,
  zoneEndorsements: endorsements,
  rankingScore: score,
  version: 1,
  updatedAt: DateTime.utc(2026, 11, 7),
);

const draft = ServiceDraft(
  categoryId: 'gasfiteria',
  title: 'Arreglo fugas',
  location: GeoPoint(-12.085678, -77.034567),
);

void main() {
  group('búsqueda del directorio', () {
    test('ignora tildes, mayúsculas y signos', () {
      expect(normalizeForSearch('¡Gásfiter, ÑANDÚ!'), 'gasfiter nandu');
    });

    test('"gásfiter" y "gasfiter" encuentran "Gasfitero a domicilio"', () {
      expect(matchesSearch('Gasfitero a domicilio', 'gásfiter'), isTrue);
      expect(matchesSearch('Gasfitero a domicilio', 'gasfiter'), isTrue);
    });

    test('tolera un error de tipeo en palabras largas, pero no dos', () {
      expect(matchesSearch('Electricista de confianza', 'electrisista'), isTrue);
      expect(matchesSearch('Electricista de confianza', 'elektrisista'), isFalse);
      expect(matchesSearch('Clases de piano', 'pan'), isFalse);
    });

    test('todas las palabras de la búsqueda deben aparecer', () {
      expect(matchesSearch('Clases de piano para niños', 'piano ninos'), isTrue);
      expect(matchesSearch('Clases de piano para niños', 'piano guitarra'), isFalse);
    });

    test('filtra por categoría, emergencia y texto, y ordena como el servidor', () {
      final services = [
        service('a', title: 'Gasfitero rápido', score: 4.9),
        service(
          'b',
          title: 'Gasfitero de la esquina',
          endorsements: 3,
          score: 3.0,
          emergency: true,
        ),
        service('c', title: 'Electricista', category: 'electricidad', emergency: true),
        service('d', title: 'Gasfitero barato', endorsements: 3, score: 4.0),
      ];
      expect(filterAndSortServices(services, const ServiceQuery()).map((s) => s.id), [
        'd',
        'b',
        'a',
        'c',
      ]);
      expect(
        filterAndSortServices(services, const ServiceQuery(emergencyOnly: true)).map((s) => s.id),
        ['b', 'c'],
      );
      expect(
        filterAndSortServices(
          services,
          const ServiceQuery(categoryId: 'electricidad'),
        ).map((s) => s.id),
        ['c'],
      );
      expect(filterAndSortServices(services, const ServiceQuery(text: 'barató')).map((s) => s.id), [
        'd',
      ]);
    });

    test('la distancia se redondea a múltiplos de 50 m', () {
      final meters = approximateDistanceMeters(
        const GeoPoint(-12.086, -77.035),
        const GeoPoint(-12.090, -77.035),
      );
      expect(meters % 50, 0);
      expect(meters, 450);
    });
  });

  group('ubicación pública (ADR 0010)', () {
    test('sin consentimiento, la copia pública tiene 3 decimales', () {
      expect(draft.publicLocation, const GeoPoint(-12.086, -77.035));
    });

    test('con consentimiento del proveedor, la copia pública es la exacta', () {
      const premises = ServiceDraft(
        categoryId: 'gasfiteria',
        title: 'Local a la calle',
        location: GeoPoint(-12.085678, -77.034567),
        showExactLocation: true,
      );
      expect(premises.publicLocation, const GeoPoint(-12.085678, -77.034567));
    });
  });

  group('validación en el celular', () {
    late InMemoryServiceDirectoryRepository directory;

    setUp(
      () => directory = InMemoryServiceDirectoryRepository(currentNeighborId: 'yo', zoneId: 'zona'),
    );
    tearDown(() => directory.close());

    test('un título de dos letras no se encola y se explica junto al campo', () async {
      expect(
        () => PublishService(directory).execute(
          const ServiceDraft(categoryId: 'gasfiteria', title: 'ab', location: GeoPoint(0, 0)),
        ),
        throwsA(isA<LocalValidationError>().having((e) => e.field, 'campo', 'title')),
      );
      expect(directory.submissions, isEmpty);
    });

    test('un radio fuera de rango no se encola', () async {
      expect(
        () => PublishService(directory).execute(
          const ServiceDraft(
            categoryId: 'gasfiteria',
            title: 'Arreglo fugas',
            location: GeoPoint(0, 0),
            coverageRadiusMeters: 50,
          ),
        ),
        throwsA(isA<LocalValidationError>().having((e) => e.field, 'campo', 'coverage')),
      );
    });

    test('el nombre del proveedor necesita al menos 2 caracteres', () async {
      expect(
        () => SaveProviderProfile(directory).execute(publicName: ' L '),
        throwsA(isA<LocalValidationError>().having((e) => e.field, 'campo', 'name')),
      );
    });
  });

  group('doble en memoria', () {
    test(
      'publicar se ve al instante como "Guardado en tu celular" y un rechazo lo quita',
      () async {
        final directory = InMemoryServiceDirectoryRepository(
          currentNeighborId: 'yo',
          zoneId: 'zona',
        );
        addTearDown(directory.close);
        final submission = await PublishService(directory).execute(draft);
        final services = await directory.watchServices().first;
        expect(services.single.submissionStatus, SubmissionStatus.savedOnPhone);
        expect(services.single.location, const GeoPoint(-12.086, -77.035));
        directory.recordResponse(
          submission.id,
          const Rejected(RejectionReason(code: 'nivel_de_confianza_insuficiente', title: 'Nivel')),
        );
        expect(await directory.watchServices().first, isEmpty);
      },
    );

    test('solo el dueño puede editar o retirar, y la edición rechazada se revierte', () async {
      final directory = InMemoryServiceDirectoryRepository(
        currentNeighborId: 'yo',
        zoneId: 'zona',
        services: [
          service('mio', provider: 'yo', title: 'Antes'),
          service('ajeno'),
        ],
      );
      addTearDown(directory.close);
      await expectLater(directory.withdrawService('ajeno'), throwsA(isA<LocalValidationError>()));
      final edit = await UpdateService(directory).execute(
        (await directory.watchService('mio').first)!,
        const ServiceDraft(categoryId: 'gasfiteria', title: 'Después', location: GeoPoint(0, 0)),
      );
      expect((await directory.watchService('mio').first)!.title, 'Después');
      directory.recordResponse(
        edit.id,
        const Rejected(RejectionReason(code: 'conflicto_de_version', title: 'Conflicto')),
      );
      final reverted = (await directory.watchService('mio').first)!;
      expect(reverted.title, 'Antes');
      expect(reverted.submissionStatus, SubmissionStatus.couldNotComplete);
    });
  });
}
