import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/geo/map_bounds.dart';
import 'package:vecinal/features/mapa/data/maplibre_region_repository.dart';
import 'package:vecinal/features/mapa/data/offline_map_store.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';

import 'support/fakes.dart';

void main() {
  late FakeOfflineMapStore store;
  late MapLibreRegionRepository repository;

  setUp(() {
    store = FakeOfflineMapStore();
    repository = MapLibreRegionRepository(store, definition: testRegion());
  });
  tearDown(() => repository.close());

  test('recupera una región completa y trata una descarga parcial como incompleta', () async {
    store.records.add(storedRegion());
    await repository.refresh();
    expect(repository.current.status, OfflineRegionStatus.ready);
    expect(repository.current.downloadedBytes, 2000000);
    store.records[0] = storedRegion(complete: false);
    await repository.refresh();
    expect(repository.current.status, OfflineRegionStatus.failed);
    expect(repository.current.failure, MapFailure.interrupted);
  });

  test('no anuncia como listo un mapa perteneciente a otro servidor', () async {
    store.records.add(
      storedRegion(definition: testRegion(styleUrl: 'https://old.example.test/map.json')),
    );
    await repository.refresh();
    expect(repository.current.status, OfflineRegionStatus.notDownloaded);
  });

  test('progreso y bytes reales; 100 % de progreso no significa éxito sin confirmación', () async {
    await repository.download();
    store.callbacks.last(const MapDownloadProgress(bytes: 1500000, fraction: 1.1));
    expect(repository.current.progress, 1);
    expect(repository.current.downloadedBytes, 1500000);
    expect(repository.current.status, OfflineRegionStatus.downloading);
    store.complete();
    await Future<void>.delayed(Duration.zero);
    expect(repository.current.status, OfflineRegionStatus.ready);
    expect(repository.current.downloadedBytes, 2000000);
  });

  test(
    'cancelar antes de recibir el identificador nativo pausa y elimina la región creada',
    () async {
      store.creation = Completer<int>();
      final downloading = repository.download();
      await Future<void>.delayed(Duration.zero);
      final cancelling = repository.cancel();
      store.creation!.complete(42);
      await Future.wait([downloading, cancelling]);
      expect(store.paused, [42]);
      expect(store.deleted, [42]);
      expect(repository.current.status, OfflineRegionStatus.notDownloaded);
    },
  );

  test('cancelar dos veces comparte la operación y no elimina dos veces', () async {
    await repository.download();
    final first = repository.cancel();
    final second = repository.cancel();
    await Future.wait([first, second]);
    expect(store.deleted, [1]);
    expect(store.paused, [1]);
  });

  test('ignora callbacks tardíos de una descarga cancelada', () async {
    await repository.download();
    final oldCallback = store.callbacks.last;
    await repository.cancel();
    await repository.download();
    oldCallback(const MapDownloadCompleted());
    expect(repository.current.status, OfflineRegionStatus.downloading);
    expect(store.starts, 2);
  });

  test('una lectura de caché no reemplaza el estado de una descarga activa', () async {
    await repository.download();
    store.callbacks.last(const MapDownloadProgress(bytes: 100, fraction: 0.5));
    await repository.refresh();
    expect(repository.current.status, OfflineRegionStatus.downloading);
    expect(repository.current.progress, 0.5);
  });

  test('un fallo al crear la región no bloquea una descarga posterior', () async {
    store.startFailure = const MapOperationException(MapFailure.downloadFailed);
    await expectLater(repository.download(), throwsA(isA<MapOperationException>()));
    expect(repository.current.status, OfflineRegionStatus.failed);
    store.startFailure = null;
    await repository.download();
    expect(repository.current.status, OfflineRegionStatus.downloading);
  });

  test('borrar solo elimina regiones propias y conserva mapas de otras funcionalidades', () async {
    final other = MapRegionDefinition(
      id: 'other',
      styleUrl: 'https://maps.example.test/other.json',
      bounds: const MapBounds(west: 0, south: 0, east: 1, north: 1),
    );
    store.records.addAll([storedRegion(), storedRegion(nativeId: 2, definition: other)]);
    await repository.delete();
    expect(store.deleted, [1]);
    expect(store.records.single.nativeId, 2);
    expect(repository.current.status, OfflineRegionStatus.notDownloaded);
  });

  test('un error de almacenamiento es visible y se puede volver a comprobar', () async {
    store.listFailure = const MapOperationException(MapFailure.storageUnavailable);
    await repository.refresh();
    expect(repository.current.failure, MapFailure.storageUnavailable);
    store.listFailure = null;
    await repository.refresh();
    expect(repository.current.status, OfflineRegionStatus.notDownloaded);
  });

  test(
    'una lectura antigua no vuelve a anunciar disponible un mapa que acaba de borrarse',
    () async {
      store.records.add(storedRegion());
      final staleListing = Completer<List<StoredMapRegion>>();
      store.nextListing = staleListing;
      final checking = repository.refresh();
      await repository.delete();
      staleListing.complete([storedRegion()]);
      await checking;
      expect(repository.current.status, OfflineRegionStatus.notDownloaded);
      expect(store.records, isEmpty);
    },
  );
}
