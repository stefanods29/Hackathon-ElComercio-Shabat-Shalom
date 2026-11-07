import 'package:vecinal/features/mapa/domain/offline_region.dart';

/// Small adapter boundary: repository tests need neither a platform channel nor a map view.
abstract interface class OfflineMapStore {
  Future<List<StoredMapRegion>> list();
  Future<int> start(MapRegionDefinition definition, void Function(MapDownloadEvent) onEvent);
  Future<void> pause(int nativeId);
  Future<void> delete(int nativeId);
}

class StoredMapRegion {
  const StoredMapRegion({
    required this.nativeId,
    required this.regionId,
    required this.cacheKey,
    required this.isComplete,
    required this.downloadedBytes,
  });

  final int nativeId;
  final String regionId;
  final String cacheKey;
  final bool isComplete;
  final int downloadedBytes;
}

sealed class MapDownloadEvent {
  const MapDownloadEvent();
}

final class MapDownloadProgress extends MapDownloadEvent {
  const MapDownloadProgress({required this.bytes, this.fraction});
  final int bytes;
  final double? fraction;
}

final class MapDownloadCompleted extends MapDownloadEvent {
  const MapDownloadCompleted();
}

final class MapDownloadFailed extends MapDownloadEvent {
  const MapDownloadFailed(this.failure);
  final MapFailure failure;
}
