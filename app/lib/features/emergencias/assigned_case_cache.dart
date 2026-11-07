import 'dart:async';
import 'dart:io';

import 'package:powersync/powersync.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';

const assignedCaseSchema = Schema([
  Table('pedidos_ayuda', [
    Column.text('detalle'),
    Column.text('creado_en'),
    Column.text('vence_en'),
  ]),
]);

class AssignedCase {
  const AssignedCase({required this.id, required this.detail, required this.expiresAt});

  final String id;
  final String detail;
  final DateTime expiresAt;
}

/// Stores only the case explicitly opened by this account, in a separately encrypted database.
class AssignedCaseCache {
  AssignedCaseCache({
    required this.path,
    required this.store,
    required String accountId,
    required this.connector,
    required this.clock,
  }) : _keyScope = 'cases.$accountId';

  final String path;
  final SecureStore store;
  final PowerSyncBackendConnector connector;
  final DateTime Function() clock;
  final String _keyScope;
  static const _caseQuery = 'SELECT id, detalle, vence_en FROM pedidos_ayuda';
  final _changes = StreamController<AssignedCase?>.broadcast();
  Future<void> _operation = Future.value();
  LocalSyncDatabase? _local;
  String? _requestedId;
  AssignedCase? _current;
  StreamSubscription<Object?>? _rows;
  SyncStreamSubscription? _subscription;
  Timer? _expiryCheck;
  bool _sessionClosed = false;

  Stream<AssignedCase?> watch() => Stream.multi((listener) {
    final updates = _changes.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = updates.cancel;
    final value = _current;
    listener.add(value != null && value.expiresAt.isAfter(clock()) ? value : null);
  });

  /// Resume the previously requested stream if the encrypted case has not expired.
  Future<void> restore() => _serialize(() async {
    if (_sessionClosed || _local != null || !await File(path).exists()) return;
    final local = await _open();
    await _review(local, restoring: true);
    final id = _requestedId;
    if (id != null) await _subscribe(local, id);
  });

  Future<void> request(String caseId) => _serialize(() async {
    if (_sessionClosed) throw StateError('La sesión ya está cerrada.');
    if (_requestedId == caseId && _rows != null) return;
    if (_local != null) await _purge();
    final local = await _open();
    _requestedId = caseId;
    await _subscribe(local, caseId);
  });

  /// Recheck on resume as well as on the timer so a suspended app never displays an expired case.
  Future<void> review() => _serialize(() async {
    final local = _local;
    if (local != null) await _review(local);
  });

  Future<void> wipeForSignOut() => _serialize(() async {
    _sessionClosed = true;
    await _purge();
  });

  Future<void> close() => _serialize(() async {
    _sessionClosed = true;
    await _stopWatching();
    await _local?.close();
    _local = null;
    _current = null;
    unawaited(_changes.close());
  });

  Future<LocalSyncDatabase> _open() async => _local = await LocalSyncDatabase.open(
    path: path,
    store: store,
    accountId: _keyScope,
    schema: assignedCaseSchema,
  );

  Future<void> _subscribe(LocalSyncDatabase local, String id) async {
    final db = local.database;
    final stream = db.syncStream('caso_asignado', {'pedido_id': id});
    final subscription = await stream.subscribe(ttl: const Duration(minutes: 1));
    _subscription = subscription;
    _rows = db
        .watch(_caseQuery, triggerOnTables: ['pedidos_ayuda'])
        .listen(
          (_) => _background(
            _serialize(() async {
              if (identical(_local, local)) await _review(local);
            }),
          ),
          onError: _changes.addError,
        );
    await db.connect(
      connector: connector,
      options: const SyncOptions(includeDefaultStreams: false, enableDiagnostics: false),
    );
    _background(
      subscription.waitForFirstSync().then(
        (_) => _serialize(() async {
          if (identical(_local, local)) await _review(local, firstSyncComplete: true);
        }),
        onError: (Object error, StackTrace stack) {
          if (identical(_local, local) && _rows != null) _changes.addError(error, stack);
        },
      ),
    );
  }

  Future<void> _review(
    LocalSyncDatabase local, {
    bool restoring = false,
    bool firstSyncComplete = false,
  }) async {
    final previous = _current;
    if (previous != null && !previous.expiresAt.isAfter(clock())) {
      await _purge();
      return;
    }
    final rows = await local.database.getAll(_caseQuery);
    if (rows.isEmpty) {
      if (restoring || firstSyncComplete || _current != null) await _purge();
      return;
    }
    final row = rows.first;
    final id = row['id'] as String?;
    final detail = row['detalle'] as String?;
    final expiresAt = DateTime.tryParse(row['vence_en'] as String? ?? '');
    if (rows.length != 1 ||
        id == null ||
        detail == null ||
        expiresAt == null ||
        !expiresAt.isAfter(clock()) ||
        (_requestedId != null && _requestedId != id)) {
      await _purge();
      return;
    }
    _requestedId = id;
    if (previous?.id != id || previous?.detail != detail || previous?.expiresAt != expiresAt) {
      _current = AssignedCase(id: id, detail: detail, expiresAt: expiresAt);
      _changes.add(_current);
    }
    _expiryCheck?.cancel();
    final remaining = expiresAt.difference(clock());
    const interval = Duration(minutes: 1);
    _expiryCheck = Timer(remaining < interval ? remaining : interval, () => _background(review()));
  }

  Future<void> _purge() async {
    _current = null;
    _changes.add(null);
    await _stopWatching();
    final local = _local;
    if (local == null) {
      await LocalSyncDatabase.discard(path: path, store: store, accountId: _keyScope);
    } else {
      await local.wipe();
    }
    _local = null;
    _requestedId = null;
  }

  Future<void> _stopWatching() async {
    _expiryCheck?.cancel();
    await _rows?.cancel();
    _rows = null;
    _subscription?.unsubscribe();
    _subscription = null;
  }

  void _background(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stack) {
        if (!_sessionClosed) _changes.addError(error, stack);
      }),
    );
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _operation.then((_) => action());
    _operation = next.then((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
