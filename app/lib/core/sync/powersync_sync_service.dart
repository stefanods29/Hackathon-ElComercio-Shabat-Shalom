import 'dart:async';

import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';

class PowerSyncSyncService implements SyncService {
  PowerSyncSyncService(this._local, this._connector);

  final LocalSyncDatabase _local;
  final VecinalConnector _connector;
  final _wipes = StreamController<void>.broadcast();
  bool _wiped = false;

  @override
  Stream<SyncStatus> watch() => Stream.multi((listener) {
    if (_wiped) {
      listener.add(SyncStatus.initial);
      listener.close();
      return;
    }
    final db = _local.database;
    var pending = 0;

    void emit() {
      if (_wiped) return;
      final status = db.currentStatus;
      listener.add(
        SyncStatus(
          connected: status.connected,
          lastSyncedAt: status.lastSyncedAt,
          pendingUploads: pending,
        ),
      );
    }

    final status = db.statusStream.listen((_) => emit(), onError: listener.addError);
    final queue = db.watch('SELECT count(*) AS pending FROM ps_crud').listen((rows) {
      pending = rows.single['pending'] as int;
      emit();
    }, onError: listener.addError);
    final wipe = _wipes.stream.listen((_) {
      listener.add(SyncStatus.initial);
      listener.close();
    });
    listener.onCancel = () => Future.wait([status.cancel(), queue.cancel(), wipe.cancel()]);
  });

  @override
  Future<void> connect() async {
    _connector.startRefreshing();
    try {
      await _local.database.connect(connector: _connector);
    } catch (_) {
      _connector.stopRefreshing();
      rethrow;
    }
  }

  @override
  Future<int> pendingUploads() async {
    if (_wiped) return 0;
    final row = await _local.database.get('SELECT count(*) AS pending FROM ps_crud');
    return row['pending'] as int;
  }

  @override
  Future<void> disconnectAndWipeLocalData() async {
    if (!_wiped) {
      _wiped = true;
      _connector.stopRefreshing();
      _wipes.add(null);
    }
    await _local.wipe();
  }
}
