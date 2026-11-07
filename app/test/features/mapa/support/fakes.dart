import 'dart:async';

import 'package:vecinal/core/geo/map_bounds.dart';
import 'package:vecinal/features/mapa/data/offline_map_store.dart';
import 'package:vecinal/features/mapa/domain/download_policy.dart';
import 'package:vecinal/features/mapa/domain/map_region_repository.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';

MapRegionDefinition testRegion({
  String styleUrl = 'https://maps.example.test/estilos/vecinal.json',
}) => MapRegionDefinition(
  id: 'lince-demo',
  bounds: const MapBounds(west: -77.07, south: -12.10, east: -77.01, north: -12.06),
  styleUrl: styleUrl,
);

StoredMapRegion storedRegion({
  int nativeId = 1,
  bool complete = true,
  int bytes = 2000000,
  MapRegionDefinition? definition,
}) {
  final selected = definition ?? testRegion();
  return StoredMapRegion(
    nativeId: nativeId,
    regionId: selected.id,
    cacheKey: selected.cacheKey,
    isComplete: complete,
    downloadedBytes: bytes,
  );
}

class FakeOfflineMapStore implements OfflineMapStore {
  final records = <StoredMapRegion>[];
  final deleted = <int>[];
  final paused = <int>[];
  final callbacks = <void Function(MapDownloadEvent)>[];
  int starts = 0;
  Completer<int>? creation;
  MapOperationException? startFailure;
  MapOperationException? listFailure;
  Completer<List<StoredMapRegion>>? nextListing;

  @override
  Future<List<StoredMapRegion>> list() async {
    if (listFailure case final failure?) throw failure;
    final pending = nextListing;
    nextListing = null;
    if (pending != null) return pending.future;
    return List.of(records);
  }

  @override
  Future<int> start(MapRegionDefinition definition, void Function(MapDownloadEvent) onEvent) async {
    starts++;
    if (startFailure case final failure?) throw failure;
    callbacks.add(onEvent);
    final id = creation == null ? starts : await creation!.future;
    records.add(storedRegion(nativeId: id, complete: false, bytes: 0, definition: definition));
    return id;
  }

  void complete({int bytes = 2000000}) {
    if (records.isNotEmpty) {
      final old = records.removeLast();
      records.add(
        StoredMapRegion(
          nativeId: old.nativeId,
          regionId: old.regionId,
          cacheKey: old.cacheKey,
          isComplete: true,
          downloadedBytes: bytes,
        ),
      );
    }
    callbacks.last(const MapDownloadCompleted());
  }

  @override
  Future<void> pause(int nativeId) async => paused.add(nativeId);

  @override
  Future<void> delete(int nativeId) async {
    deleted.add(nativeId);
    records.removeWhere((record) => record.nativeId == nativeId);
  }
}

class FakeMapConnectionMonitor implements MapConnectionMonitor {
  FakeMapConnectionMonitor([this.connection = MapConnection.wifi]);
  MapConnection connection;
  final _events = StreamController<MapConnection>.broadcast();

  void emit(MapConnection next) {
    connection = next;
    _events.add(next);
  }

  @override
  Future<MapConnection> current() async => connection;

  @override
  Stream<MapConnection> watch() => _events.stream;

  Future<void> close() => _events.close();
}

class FakeMapRegionRepository implements MapRegionRepository {
  FakeMapRegionRepository({OfflineRegionStatus status = OfflineRegionStatus.notDownloaded}) {
    _current = OfflineRegion(definition: testRegion(), status: status, downloadedBytes: 2000000);
  }

  late OfflineRegion _current;
  final _events = StreamController<List<OfflineRegion>>.broadcast();
  int downloads = 0;
  int cancellations = 0;
  int deletions = 0;
  int refreshes = 0;
  MapOperationException? downloadFailure;

  @override
  OfflineRegion get current => _current;

  void emit(OfflineRegionStatus status, {double? progress, int bytes = 0}) {
    _current = OfflineRegion(
      definition: testRegion(),
      status: status,
      progress: progress,
      downloadedBytes: bytes,
    );
    _events.add([_current]);
  }

  @override
  Stream<List<OfflineRegion>> watchRegions() => Stream.multi((listener) {
    final subscription = _events.stream.listen(listener.addSync, onDone: listener.closeSync);
    listener.addSync([_current]);
    listener.onCancel = subscription.cancel;
  });

  @override
  Future<void> refresh() async {
    refreshes++;
  }

  @override
  Future<void> download() async {
    if (downloadFailure case final failure?) throw failure;
    downloads++;
    emit(OfflineRegionStatus.downloading, progress: 0);
  }

  @override
  Future<void> cancel() async {
    cancellations++;
    emit(OfflineRegionStatus.notDownloaded);
  }

  @override
  Future<void> delete() async {
    deletions++;
    emit(OfflineRegionStatus.notDownloaded);
  }

  Future<void> close() => _events.close();
}
