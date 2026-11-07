import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as native;
import 'package:vecinal/features/mapa/data/offline_map_store.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';

/// The only persistence adapter that knows MapLibre's global offline API.
class MapLibreOfflineMapStore implements OfflineMapStore {
  const MapLibreOfflineMapStore();

  static const _regionIdKey = 'vecinalRegionId';
  static const _cacheKey = 'vecinalCacheKey';

  @override
  Future<List<StoredMapRegion>> list() => _translate(() async {
    final regions = await native.getListOfRegions();
    final result = <StoredMapRegion>[];
    for (final region in regions) {
      final regionId = region.metadata[_regionIdKey];
      final cacheKey = region.metadata[_cacheKey];
      if (regionId is! String || cacheKey is! String) continue;
      final status = await native.getOfflineRegionStatus(region.id);
      result.add(
        StoredMapRegion(
          nativeId: region.id,
          regionId: regionId,
          cacheKey: cacheKey,
          isComplete: status.isComplete,
          downloadedBytes: status.completedResourceSize,
        ),
      );
    }
    return result;
  });

  @override
  Future<int> start(MapRegionDefinition definition, void Function(MapDownloadEvent) onEvent) =>
      _translate(() async {
        final region = await native.downloadOfflineRegion(
          native.OfflineRegionDefinition(
            bounds: native.LatLngBounds(
              southwest: native.LatLng(definition.bounds.south, definition.bounds.west),
              northeast: native.LatLng(definition.bounds.north, definition.bounds.east),
            ),
            mapStyleUrl: definition.styleUrl,
            minZoom: definition.minZoom,
            maxZoom: definition.maxZoom,
          ),
          metadata: {_regionIdKey: definition.id, _cacheKey: definition.cacheKey},
          onEvent: (event) {
            if (event is native.InProgress) {
              final fraction = event.requiredResourceCount > 0
                  ? event.completedResourceCount / event.requiredResourceCount
                  : null;
              onEvent(MapDownloadProgress(bytes: event.completedResourceSize, fraction: fraction));
            } else if (event is native.Success) {
              onEvent(const MapDownloadCompleted());
            } else if (event is native.Error) {
              onEvent(MapDownloadFailed(_failureFor(event.cause)));
            }
          },
        );
        return region.id;
      });

  @override
  Future<void> pause(int nativeId) => _translate(() => native.pauseOfflineRegionDownload(nativeId));

  @override
  Future<void> delete(int nativeId) => _translate(() => native.deleteOfflineRegion(nativeId));

  Future<T> _translate<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      throw MapOperationException(_failureFor(error));
    } on MissingPluginException {
      throw const MapOperationException(MapFailure.unsupported);
    } on UnsupportedError {
      throw const MapOperationException(MapFailure.unsupported);
    }
  }

  static MapFailure _failureFor(PlatformException error) => switch (error.code) {
    'TILE_COUNT_LIMIT_EXCEEDED' => MapFailure.tileLimitExceeded,
    'OFFLINE_DATABASE_ERROR' => MapFailure.storageUnavailable,
    _ => MapFailure.downloadFailed,
  };
}
