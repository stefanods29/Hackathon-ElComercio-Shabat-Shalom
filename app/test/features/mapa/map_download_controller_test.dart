import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/features/mapa/data/providers.dart';
import 'package:vecinal/features/mapa/domain/download_policy.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';
import 'package:vecinal/features/mapa/presentation/map_download_controller.dart';

import 'support/fakes.dart';

void main() {
  late FakeMapConnectionMonitor monitor;
  late FakeMapRegionRepository repository;
  late ProviderContainer container;
  late MapDownloadController controller;

  setUp(() async {
    monitor = FakeMapConnectionMonitor();
    repository = FakeMapRegionRepository();
    container = ProviderContainer(
      overrides: [
        mapConnectionMonitorProvider.overrideWithValue(monitor),
        mapRegionRepositoryProvider.overrideWithValue(repository),
        offlineMapSupportedProvider.overrideWithValue(true),
      ],
    );
    container.listen(mapDownloadControllerProvider, (_, next) {});
    controller = container.read(mapDownloadControllerProvider.notifier);
    await controller.refresh();
    await container.pump();
  });
  tearDown(() async {
    container.dispose();
    await monitor.close();
    await repository.close();
  });

  test('bloquea los datos móviles por defecto sin llamar al repositorio', () async {
    monitor.connection = MapConnection.other;
    await controller.download();
    expect(repository.downloads, 0);
    expect(container.read(mapDownloadControllerProvider).failure, MapFailure.wifiRequired);
  });

  test('comprueba la conexión actual al tocar descargar, no una lectura anterior', () async {
    monitor.connection = MapConnection.unavailable;
    controller.setAllowMobileData(true);
    await controller.download();
    expect(repository.downloads, 0);
    expect(container.read(mapDownloadControllerProvider).failure, MapFailure.noConnection);
  });

  test('permite datos móviles solo tras la autorización del vecino', () async {
    monitor.connection = MapConnection.other;
    controller.setAllowMobileData(true);
    await controller.download();
    expect(repository.downloads, 1);
    expect(container.read(mapDownloadControllerProvider).failure, isNull);
  });

  test('al perder Wi-Fi cancela la descarga activa y explica cómo continuar', () async {
    await controller.download();
    final feedback = Completer<void>();
    container.listen(mapDownloadControllerProvider, (_, state) {
      if (state.failure == MapFailure.wifiRequired && !feedback.isCompleted) feedback.complete();
    });
    monitor.emit(MapConnection.other);
    await feedback.future;
    expect(repository.cancellations, 1);
    expect(repository.current.status, OfflineRegionStatus.notDownloaded);
    expect(container.read(mapDownloadControllerProvider).failure, MapFailure.wifiRequired);
  });

  test('retirar el permiso durante una descarga móvil la detiene', () async {
    monitor.connection = MapConnection.other;
    controller.setAllowMobileData(true);
    await controller.download();
    controller.setAllowMobileData(false);
    await container.pump();
    expect(repository.cancellations, 1);
  });

  test('un error del repositorio se transforma en estado recuperable', () async {
    repository.downloadFailure = const MapOperationException(MapFailure.storageUnavailable);
    await controller.download();
    expect(container.read(mapDownloadControllerProvider).failure, MapFailure.storageUnavailable);
    expect(container.read(mapDownloadControllerProvider).action, MapDownloadAction.none);
    repository.downloadFailure = null;
    await controller.download();
    expect(repository.downloads, 1);
  });
}
