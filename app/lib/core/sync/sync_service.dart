import 'dart:async';

/// What the UI needs to know about sync so it never over-promises (section 3.4).
class SyncStatus {
  const SyncStatus({required this.connected, this.lastSyncedAt, this.pendingUploads = 0});

  static const initial = SyncStatus(connected: false);

  final bool connected;

  /// Last time everything pending was received from the server; `null` if never.
  final DateTime? lastSyncedAt;

  /// Actions in the local queue that have not reached the server yet.
  final int pendingUploads;
}

/// Port of the sync engine. The real PowerSync implementation belongs to Lot A.
abstract interface class SyncService {
  Stream<SyncStatus> watch();

  Future<void> connect();

  /// Actions in the local queue right now, read from the database rather than from the last
  /// status (it decides whether the zone can change).
  Future<int> pendingUploads();

  /// Sign-out or a lost phone report: wipes the local database completely (section 8.4).
  Future<void> disconnectAndWipeLocalData();
}

/// Double to build the UI in parallel and for tests: the status is changed by hand.
class FakeSyncService implements SyncService {
  FakeSyncService([SyncStatus initial = SyncStatus.initial]) : _current = initial;

  final _changes = StreamController<SyncStatus>.broadcast();
  SyncStatus _current;
  bool localDataWiped = false;

  SyncStatus get current => _current;

  void simulate(SyncStatus status) {
    _current = status;
    _changes.add(status);
  }

  @override
  Stream<SyncStatus> watch() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<int> pendingUploads() async => _current.pendingUploads;

  @override
  Future<void> connect() async {
    simulate(
      SyncStatus(
        connected: true,
        lastSyncedAt: DateTime.now(),
        pendingUploads: _current.pendingUploads,
      ),
    );
  }

  @override
  Future<void> disconnectAndWipeLocalData() async {
    localDataWiped = true;
    simulate(SyncStatus.initial);
  }

  Future<void> close() => _changes.close();
}
