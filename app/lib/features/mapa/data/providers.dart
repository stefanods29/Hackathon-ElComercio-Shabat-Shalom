import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/features/mapa/data/connectivity_map_monitor.dart';
import 'package:vecinal/features/mapa/data/maplibre_offline_map_store.dart';
import 'package:vecinal/features/mapa/data/maplibre_region_repository.dart';
import 'package:vecinal/features/mapa/data/offline_map_store.dart';
import 'package:vecinal/features/mapa/domain/download_policy.dart';
import 'package:vecinal/features/mapa/domain/map_region_repository.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';

final mapRegionDefinitionProvider = Provider<MapRegionDefinition>((ref) {
  final environment = ref.watch(environmentProvider);
  return MapRegionDefinition(
    id: 'lince-demo',
    bounds: environment.mapBounds,
    styleUrl: environment.mapStyleUrl,
  );
});

final offlineMapStoreProvider = Provider<OfflineMapStore>((ref) => const MapLibreOfflineMapStore());

final mapRegionRepositoryProvider = Provider<MapRegionRepository>((ref) {
  final repository = MapLibreRegionRepository(
    ref.watch(offlineMapStoreProvider),
    definition: ref.watch(mapRegionDefinitionProvider),
  );
  unawaited(repository.refresh());
  ref.onDispose(() {
    unawaited(
      repository.close().catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack, library: 'mapa'),
        );
      }),
    );
  });
  return repository;
});

final offlineRegionsProvider = StreamProvider<List<OfflineRegion>>(
  (ref) => ref.watch(mapRegionRepositoryProvider).watchRegions(),
);

final mapConnectionMonitorProvider = Provider<MapConnectionMonitor>(
  (ref) => ConnectivityMapMonitor(Connectivity()),
);

final offlineMapSupportedProvider = Provider<bool>(
  (ref) => !kIsWeb && [TargetPlatform.android, TargetPlatform.iOS].contains(defaultTargetPlatform),
);
