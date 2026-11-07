import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/mapa/data/providers.dart';
import 'package:vecinal/features/mapa/domain/download_policy.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';

enum MapDownloadAction { none, starting, cancelling, deleting }

class MapDownloadState {
  const MapDownloadState({
    this.connection = MapConnection.unknown,
    this.allowMobileData = false,
    this.action = MapDownloadAction.none,
    this.failure,
  });

  final MapConnection connection;
  final bool allowMobileData;
  final MapDownloadAction action;
  final MapFailure? failure;

  MapDownloadState withChanges({
    MapConnection? connection,
    bool? allowMobileData,
    MapDownloadAction? action,
    MapFailure? failure,
    bool clearFailure = false,
  }) => MapDownloadState(
    connection: connection ?? this.connection,
    allowMobileData: allowMobileData ?? this.allowMobileData,
    action: action ?? this.action,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}

final mapDownloadControllerProvider = NotifierProvider<MapDownloadController, MapDownloadState>(
  MapDownloadController.new,
);

/// View model: enforces the connection policy and exposes typed, localizable feedback.
class MapDownloadController extends Notifier<MapDownloadState> {
  int _operation = 0;

  @override
  MapDownloadState build() {
    final monitor = ref.watch(mapConnectionMonitorProvider);
    // Keep observing an active native download even when the user navigates away from the map.
    final subscription = monitor.watch().listen(
      _connectionChanged,
      onError: (Object error, StackTrace stack) => _connectionChanged(MapConnection.unknown),
    );
    ref.onDispose(subscription.cancel);
    return const MapDownloadState();
  }

  Future<void> refresh() async {
    final connection = await ref.read(mapConnectionMonitorProvider).current();
    if (!ref.mounted) return;
    _connectionChanged(connection);
    await ref.read(mapRegionRepositoryProvider).refresh();
  }

  void setAllowMobileData(bool value) {
    state = state.withChanges(allowMobileData: value, clearFailure: true);
    _enforceConnectionPolicy();
  }

  Future<void> download() => _run(MapDownloadAction.starting, () async {
    if (!ref.read(offlineMapSupportedProvider)) {
      throw const MapOperationException(MapFailure.unsupported);
    }
    final connection = await ref.read(mapConnectionMonitorProvider).current();
    if (!ref.mounted) return;
    _connectionChanged(connection);
    if (!permitsMapDownload(connection, allowMobileData: state.allowMobileData)) {
      throw MapOperationException(_policyFailure(connection));
    }
    await ref.read(mapRegionRepositoryProvider).download();
  });

  Future<void> cancel() =>
      _run(MapDownloadAction.cancelling, () => ref.read(mapRegionRepositoryProvider).cancel());

  Future<void> delete() =>
      _run(MapDownloadAction.deleting, () => ref.read(mapRegionRepositoryProvider).delete());

  void _connectionChanged(MapConnection connection) {
    if (!ref.mounted) return;
    state = state.withChanges(connection: connection);
    _enforceConnectionPolicy();
  }

  MapFailure _policyFailure(MapConnection connection) =>
      connection == MapConnection.wifi || connection == MapConnection.other
      ? MapFailure.wifiRequired
      : MapFailure.noConnection;

  void _enforceConnectionPolicy() {
    if (permitsMapDownload(state.connection, allowMobileData: state.allowMobileData) ||
        state.action == MapDownloadAction.cancelling ||
        ref.read(mapRegionRepositoryProvider).current.status != OfflineRegionStatus.downloading) {
      return;
    }
    final failure = _policyFailure(state.connection);
    unawaited(
      _run(MapDownloadAction.cancelling, () async {
        await ref.read(mapRegionRepositoryProvider).cancel();
        if (ref.mounted) state = state.withChanges(failure: failure);
      }),
    );
  }

  Future<void> _run(MapDownloadAction action, Future<void> Function() operation) async {
    if (state.action != MapDownloadAction.none &&
        !(action == MapDownloadAction.cancelling && state.action == MapDownloadAction.starting)) {
      return;
    }
    final token = ++_operation;
    state = state.withChanges(action: action, clearFailure: true);
    try {
      await operation();
    } on MapOperationException catch (error) {
      if (ref.mounted && token == _operation) state = state.withChanges(failure: error.failure);
    } finally {
      if (ref.mounted && token == _operation) {
        state = state.withChanges(action: MapDownloadAction.none);
      }
    }
  }
}
