import 'package:vecinal/features/mapa/domain/offline_region.dart';

/// Owns the selected zone's downloaded map; native identifiers never reach the screen.
abstract interface class MapRegionRepository {
  OfflineRegion get current;
  Stream<List<OfflineRegion>> watchRegions();
  Future<void> refresh();
  Future<void> download();
  Future<void> cancel();
  Future<void> delete();
}
