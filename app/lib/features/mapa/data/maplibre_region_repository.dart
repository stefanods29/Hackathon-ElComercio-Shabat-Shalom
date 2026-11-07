import 'dart:async';

import 'package:vecinal/features/mapa/data/offline_map_store.dart';
import 'package:vecinal/features/mapa/domain/map_region_repository.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';

/// Coordinates native storage without exposing platform handles or mutable snapshots.
class MapLibreRegionRepository implements MapRegionRepository {
  MapLibreRegionRepository(this._store, {required this.definition})
    : _current = OfflineRegion(definition: definition, status: OfflineRegionStatus.checking);

  final MapRegionDefinition definition;
  final OfflineMapStore _store;
  final _changes = StreamController<List<OfflineRegion>>.broadcast();
  OfflineRegion _current;
  _DownloadOperation? _active;
  bool _deleting = false;
  bool _closed = false;
  int _revision = 0;

  @override
  OfflineRegion get current => _current;

  @override
  Stream<List<OfflineRegion>> watchRegions() => Stream.multi((listener) {
    final subscription = _changes.stream.listen(
      listener.addSync,
      onError: listener.addErrorSync,
      onDone: listener.closeSync,
    );
    listener.addSync([_current]);
    listener.onCancel = subscription.cancel;
  });

  @override
  Future<void> refresh() async {
    if (_closed || _active != null || _deleting) return;
    // A slow cache read may finish after a newer read or a completed deletion.
    final revision = ++_revision;
    try {
      final records = await _store.list();
      if (_closed || revision != _revision || _active != null || _deleting) return;
      final matching = records.where((record) => record.cacheKey == definition.cacheKey).toList()
        ..sort((a, b) => (b.isComplete ? 1 : 0).compareTo(a.isComplete ? 1 : 0));
      if (matching.isEmpty) {
        _publish(OfflineRegionStatus.notDownloaded);
      } else {
        final record = matching.first;
        _publish(
          record.isComplete ? OfflineRegionStatus.ready : OfflineRegionStatus.failed,
          bytes: record.downloadedBytes,
          progress: record.isComplete ? 1 : null,
          failure: record.isComplete ? null : MapFailure.interrupted,
        );
      }
    } on MapOperationException catch (error) {
      if (revision == _revision && _active == null && !_deleting) {
        _publish(OfflineRegionStatus.failed, failure: error.failure);
      }
    }
  }

  @override
  Future<void> download() async {
    if (_closed || _active != null || _deleting || _current.status == OfflineRegionStatus.ready) {
      return;
    }
    final operation = _DownloadOperation();
    _revision++;
    _active = operation;
    _publish(OfflineRegionStatus.downloading);
    try {
      await _removeOwnedRegions();
      if (operation.cancelRequested) {
        operation.created.complete(null);
        return;
      }
      final nativeId = await _store.start(
        definition,
        (event) => _onDownloadEvent(operation, event),
      );
      operation.created.complete(nativeId);
      if (operation.terminal && !operation.cancelRequested && identical(_active, operation)) {
        _active = null;
        if (_current.status == OfflineRegionStatus.ready) await refresh();
      }
    } on MapOperationException catch (error) {
      if (!operation.created.isCompleted) operation.created.complete(null);
      if (!operation.cancelRequested && identical(_active, operation)) {
        _active = null;
        _publish(OfflineRegionStatus.failed, failure: error.failure);
        rethrow;
      }
    }
  }

  void _onDownloadEvent(_DownloadOperation operation, MapDownloadEvent event) {
    // Late callbacks from a cancelled/replaced download must never revive its UI state.
    if (_closed ||
        operation.terminal ||
        operation.cancelRequested ||
        !identical(_active, operation)) {
      return;
    }
    switch (event) {
      case MapDownloadProgress(:final bytes, :final fraction):
        final progress = fraction != null && fraction.isFinite
            ? fraction.clamp(0.0, 1.0).toDouble()
            : null;
        _publish(OfflineRegionStatus.downloading, bytes: bytes < 0 ? 0 : bytes, progress: progress);
      case MapDownloadCompleted():
        operation.terminal = true;
        _publish(OfflineRegionStatus.ready, bytes: _current.downloadedBytes, progress: 1);
      case MapDownloadFailed(:final failure):
        operation.terminal = true;
        _publish(OfflineRegionStatus.failed, bytes: _current.downloadedBytes, failure: failure);
    }
    if (operation.terminal && operation.created.isCompleted) {
      _active = null;
      if (_current.status == OfflineRegionStatus.ready) unawaited(refresh());
    }
  }

  @override
  Future<void> cancel() {
    final operation = _active;
    if (operation == null) return Future.value();
    _revision++;
    operation.cancelRequested = true;
    return operation.cancellation ??= _cancel(operation);
  }

  Future<void> _cancel(_DownloadOperation operation) async {
    try {
      // The native ID is assigned asynchronously. Cancellation also works before it arrives.
      final nativeId = await operation.created.future;
      if (nativeId != null) {
        await _store.pause(nativeId);
        await _store.delete(nativeId);
      }
      _publish(OfflineRegionStatus.notDownloaded);
    } on MapOperationException catch (error) {
      _publish(OfflineRegionStatus.failed, failure: error.failure);
      rethrow;
    } finally {
      if (identical(_active, operation)) _active = null;
    }
  }

  @override
  Future<void> delete() async {
    if (_closed || _deleting) return;
    _revision++;
    _deleting = true;
    try {
      if (_active != null) await cancel();
      await _removeOwnedRegions();
      _publish(OfflineRegionStatus.notDownloaded);
    } on MapOperationException catch (error) {
      _publish(OfflineRegionStatus.failed, failure: error.failure);
      rethrow;
    } finally {
      _deleting = false;
    }
  }

  Future<void> _removeOwnedRegions() async {
    final records = await _store.list();
    for (final record in records.where((record) => record.regionId == definition.id)) {
      await _store.delete(record.nativeId);
    }
  }

  void _publish(
    OfflineRegionStatus status, {
    int bytes = 0,
    double? progress,
    MapFailure? failure,
  }) {
    if (_closed) return;
    _current = OfflineRegion(
      definition: definition,
      status: status,
      downloadedBytes: bytes,
      progress: progress,
      failure: failure,
    );
    _changes.add([_current]);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      await cancel();
    } finally {
      await _changes.close();
    }
  }
}

class _DownloadOperation {
  final created = Completer<int?>();
  bool cancelRequested = false;
  bool terminal = false;
  Future<void>? cancellation;
}
