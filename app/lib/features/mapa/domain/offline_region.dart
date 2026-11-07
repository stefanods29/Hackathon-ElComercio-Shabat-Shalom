import 'package:vecinal/core/geo/map_bounds.dart';

/// A download definition independent of Flutter and the map vendor.
class MapRegionDefinition {
  MapRegionDefinition({
    required this.id,
    required this.bounds,
    required this.styleUrl,
    this.minZoom = 10,
    this.maxZoom = 15,
  }) {
    final uri = Uri.tryParse(styleUrl);
    if (id.isEmpty ||
        !bounds.isValid ||
        !minZoom.isFinite ||
        !maxZoom.isFinite ||
        minZoom < 0 ||
        maxZoom > 22 ||
        minZoom > maxZoom ||
        uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw ArgumentError('Invalid offline map region definition.');
    }
  }

  final String id;
  final MapBounds bounds;
  final String styleUrl;
  final double minZoom;
  final double maxZoom;

  /// Stable across launches; a cache for another server or area is never claimed as this one.
  String get cacheKey =>
      '$id|$styleUrl|$minZoom|$maxZoom|'
      '${bounds.west},${bounds.south},${bounds.east},${bounds.north}';
}

enum OfflineRegionStatus { checking, notDownloaded, downloading, ready, failed }

enum MapFailure {
  wifiRequired,
  noConnection,
  unsupported,
  storageUnavailable,
  downloadFailed,
  tileLimitExceeded,
  interrupted,
}

class MapOperationException implements Exception {
  const MapOperationException(this.failure);
  final MapFailure failure;
}

/// Immutable snapshot. Only a confirmed native completion produces [OfflineRegionStatus.ready].
class OfflineRegion {
  const OfflineRegion({
    required this.definition,
    required this.status,
    this.downloadedBytes = 0,
    this.progress,
    this.failure,
  });

  final MapRegionDefinition definition;
  final OfflineRegionStatus status;
  final int downloadedBytes;

  /// A fraction from 0 to 1; null means the native engine cannot yet estimate the total.
  final double? progress;
  final MapFailure? failure;
}
