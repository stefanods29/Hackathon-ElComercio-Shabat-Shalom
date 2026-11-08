import 'dart:async';
import 'dart:io';

import 'package:powersync/powersync.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';

const assignedCaseSchema = Schema([
  Table('pedidos_ayuda', [
    Column.text('necesidad'),
    Column.text('prioridad'),
    Column.text('estado'),
    Column.integer('version'),
    Column.text('celda'),
    Column.text('creado_en'),
    Column.text('vence_en'),
  ]),
  Table.localOnly('acceso_caso', [Column.text('autorizacion_id'), Column.text('vence_en')]),
]);

const assignedLocationSchema = Schema([
  Table('ubicaciones_casos', [Column.text('descripcion'), Column.real('lat'), Column.real('lng')]),
]);

enum AssignedCaseScope {
  summary('resumen', 'caso_asignado'),
  exactLocation('exacta', 'caso_ubicacion_exacta');

  const AssignedCaseScope(this.apiValue, this.stream);
  final String apiValue;
  final String stream;
}

typedef AssignedCasePermit = ({String authorizationId, DateTime expiresAt});

/// The API must audit the opening before issuing a session-bound permit for the requested scope.
typedef AuthorizeAssignedCase =
    Future<AssignedCasePermit?> Function(String caseId, AssignedCaseScope scope);

typedef SubscribeToAssignedCase =
    Future<SyncStreamSubscription> Function(
      PowerSyncDatabase database,
      String stream,
      Map<String, Object?> parameters,
    );

typedef AssignedCaseLocation = ({double latitude, double longitude, String description});

class AssignedCase {
  const AssignedCase({
    required this.id,
    required this.need,
    required this.priority,
    required this.stage,
    required this.version,
    required this.cell,
    required this.expiresAt,
    this.location,
  });

  final String id;
  final String need;
  final String priority;
  final HelpRequestStage stage;
  final int version;
  final String? cell;
  final DateTime expiresAt;
  final AssignedCaseLocation? location;
}

/// One explicitly opened case per account. Exact location has its own erasable database and key.
class AssignedCaseCache {
  AssignedCaseCache({
    required this.path,
    required this.store,
    required this.accountId,
    required PowerSyncBackendConnector connector,
    required this.clock,
    this.authorize,
    this.maxLocalAge = const Duration(hours: 24),
    SubscribeToAssignedCase? subscribe,
  }) : _subscribe = subscribe ?? ((db, stream, params) => _connect(db, connector, stream, params));

  static String _scope(String accountId) => 'cases.$accountId';
  static String _exactScope(String accountId) => 'cases.exact.$accountId';
  static String _exactPath(String path) => '$path.exact';

  static Future<void> discard({
    required String path,
    required SecureStore store,
    required String accountId,
  }) async {
    await Future.wait([
      LocalSyncDatabase.discard(path: path, store: store, accountId: _scope(accountId)),
      LocalSyncDatabase.discard(
        path: _exactPath(path),
        store: store,
        accountId: _exactScope(accountId),
      ),
    ]);
  }

  final String path;
  final SecureStore store;
  final DateTime Function() clock;
  final AuthorizeAssignedCase? authorize;
  final Duration maxLocalAge;
  final String accountId;
  final SubscribeToAssignedCase _subscribe;
  static const _summaryQuery = 'SELECT * FROM pedidos_ayuda';
  static const _exactQuery = 'SELECT * FROM ubicaciones_casos';
  final _changes = StreamController<AssignedCase?>.broadcast();
  Future<void> _operation = Future.value();
  _CaseFeed? _summary;
  _CaseFeed? _exact;
  AssignedCase? _current;
  Timer? _expiryCheck;
  bool _sessionClosed = false;

  Stream<AssignedCase?> watch() => Stream.multi((listener) {
    final updates = _changes.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = updates.cancel;
    final current = _current;
    if (current == null || !current.expiresAt.isAfter(clock())) {
      listener.add(null);
    } else if (_exact?.permit.expiresAt.isAfter(clock()) == false) {
      listener.add(_withLocation(current, null));
    } else {
      listener.add(current);
    }
  });

  /// Only the previously authorized summary can resume. Exact access requires a new opening.
  Future<void> restore() => _serialize(() async {
    if (_sessionClosed || _summary != null) return;
    await _discardExact();
    if (!await File(path).exists()) return;
    if (authorize == null) {
      await LocalSyncDatabase.discard(path: path, store: store, accountId: _scope(accountId));
      return;
    }
    final local = await _open(exact: false);
    final permits = await local.database.getAll('SELECT * FROM acceso_caso');
    final row = permits.singleOrNull;
    final expiresAt = DateTime.tryParse(row?['vence_en'] as String? ?? '');
    final permitId = row?['autorizacion_id'] as String?;
    if (row == null ||
        permitId == null ||
        permitId.isEmpty ||
        expiresAt == null ||
        !expiresAt.isAfter(clock())) {
      await local.wipe();
      return;
    }
    final feed = _summary = _CaseFeed(local, row['id'] as String, (
      authorizationId: permitId,
      expiresAt: expiresAt,
    ));
    await _review(requireSummary: true);
    if (identical(_summary, feed)) await _start(feed, AssignedCaseScope.summary);
  });

  Future<void> request(String caseId) => _serialize(() async {
    _requireOpen();
    await _review();
    if (_summary?.caseId == caseId) return;
    await _purge();
    final permit = await _requirePermit(caseId, AssignedCaseScope.summary);
    final local = await _open(exact: false);
    final feed = _summary = _CaseFeed(local, caseId, permit);
    try {
      await local.database.execute(
        'INSERT INTO acceso_caso (id, autorizacion_id, vence_en) VALUES (?, ?, ?)',
        [caseId, permit.authorizationId, permit.expiresAt.toUtc().toIso8601String()],
      );
      await _start(feed, AssignedCaseScope.summary);
    } catch (_) {
      await _purge();
      rethrow;
    }
  });

  Future<void> requestExact(String caseId) => _serialize(() async {
    _requireOpen();
    await _review();
    if (_current?.id != caseId || _current?.stage != HelpRequestStage.onTheWay) {
      throw StateError('La ubicación exacta requiere un caso asignado en camino.');
    }
    if (_exact != null) return;
    final permit = await _requirePermit(caseId, AssignedCaseScope.exactLocation);
    await _review();
    if (_current?.id != caseId || _current?.stage != HelpRequestStage.onTheWay) {
      throw StateError('La ubicación exacta ya no está disponible.');
    }
    final local = await _open(exact: true);
    final feed = _exact = _CaseFeed(local, caseId, permit);
    try {
      await _start(feed, AssignedCaseScope.exactLocation);
    } catch (_) {
      await _purgeExact();
      rethrow;
    }
  });

  Future<void> review() => _serialize(_review);

  Future<void> wipeForSignOut() => _serialize(() async {
    _sessionClosed = true;
    await _purge();
  });

  Future<void> close() => _serialize(() async {
    if (_changes.isClosed) return;
    _sessionClosed = true;
    _expiryCheck?.cancel();
    _publish(null);
    await _purgeExact();
    final summary = _summary;
    _summary = null;
    await summary?.stop();
    await summary?.local.close();
    unawaited(_changes.close());
  });

  void _requireOpen() {
    if (_sessionClosed) throw StateError('La sesión ya está cerrada.');
  }

  Future<AssignedCasePermit> _requirePermit(String caseId, AssignedCaseScope scope) async {
    final permit = await authorize?.call(caseId, scope);
    if (permit == null || permit.authorizationId.isEmpty || !permit.expiresAt.isAfter(clock())) {
      throw StateError('La apertura del caso no fue autorizada.');
    }
    return permit;
  }

  Future<LocalSyncDatabase> _open({required bool exact}) => LocalSyncDatabase.open(
    path: exact ? _exactPath(path) : path,
    store: store,
    accountId: exact ? _exactScope(accountId) : _scope(accountId),
    schema: exact ? assignedLocationSchema : assignedCaseSchema,
  );

  static Future<SyncStreamSubscription> _connect(
    PowerSyncDatabase db,
    PowerSyncBackendConnector connector,
    String stream,
    Map<String, Object?> parameters,
  ) async {
    final subscription = await db.syncStream(stream, parameters).subscribe(ttl: Duration.zero);
    try {
      await db.connect(
        connector: connector,
        options: const SyncOptions(includeDefaultStreams: false, enableDiagnostics: false),
      );
      return subscription;
    } catch (_) {
      subscription.unsubscribe();
      rethrow;
    }
  }

  Future<void> _start(_CaseFeed feed, AssignedCaseScope scope) async {
    final exact = scope == AssignedCaseScope.exactLocation;
    final db = feed.local.database;
    final subscription = await _subscribe(db, scope.stream, {
      'pedido_id': feed.caseId,
      'autorizacion_id': feed.permit.authorizationId,
    });
    feed.subscription = subscription;
    feed.rows = db
        .watch(
          exact ? _exactQuery : _summaryQuery,
          triggerOnTables: [exact ? 'ubicaciones_casos' : 'pedidos_ayuda'],
        )
        .listen(
          (_) => _background(
            _serialize(() async {
              if (identical(exact ? _exact : _summary, feed)) await _review();
            }),
          ),
          onError: _changes.addError,
        );
    _scheduleReview();
    _background(
      subscription.waitForFirstSync().then(
        (_) => _serialize(() async {
          if (identical(exact ? _exact : _summary, feed)) {
            await _review(requireSummary: !exact, requireExact: exact);
          }
        }),
        onError: (Object error, StackTrace stack) {
          if (identical(exact ? _exact : _summary, feed)) _changes.addError(error, stack);
        },
      ),
    );
  }

  Future<void> _review({bool requireSummary = false, bool requireExact = false}) async {
    final summary = _summary;
    if (summary == null) return;
    final now = clock();
    final displayedDeadline = _current?.expiresAt;
    if (!summary.permit.expiresAt.isAfter(now) ||
        (displayedDeadline != null && !displayedDeadline.isAfter(now))) {
      await _purge();
      return;
    }
    final rows = await summary.local.database.getAll(_summaryQuery);
    if (rows.isEmpty && !requireSummary && _current == null) {
      _scheduleReview();
      return;
    }
    final row = rows.singleOrNull;
    final stage = HelpRequestStage.fromApi(row?['estado']);
    final expires = DateTime.tryParse(row?['vence_en'] as String? ?? '');
    final localDeadline = DateTime.tryParse(row?['creado_en'] as String? ?? '')?.add(maxLocalAge);
    final need = row?['necesidad'] as String?;
    final priority = row?['prioridad'] as String?;
    final version = row?['version'] as int?;
    if (row?['id'] != summary.caseId ||
        need == null ||
        priority == null ||
        version == null ||
        expires == null ||
        !expires.isAfter(now) ||
        localDeadline == null ||
        !localDeadline.isAfter(now) ||
        (stage != HelpRequestStage.sent &&
            stage != HelpRequestStage.seen &&
            stage != HelpRequestStage.onTheWay)) {
      await _purge();
      return;
    }

    final deadline = _earlier(localDeadline, _earlier(expires, summary.permit.expiresAt));
    final exact = _exact;
    AssignedCaseLocation? location;
    if (exact != null) {
      if (stage != HelpRequestStage.onTheWay || !exact.permit.expiresAt.isAfter(now)) {
        _publish(_current == null ? null : _withLocation(_current!, null));
        await _purgeExact();
      } else {
        final locations = await exact.local.database.getAll(_exactQuery);
        final detail = locations.singleOrNull;
        final lat = (detail?['lat'] as num?)?.toDouble();
        final lng = (detail?['lng'] as num?)?.toDouble();
        final description = detail?['descripcion'] as String?;
        if (detail?['id'] == summary.caseId &&
            lat != null &&
            lng != null &&
            lat.isFinite &&
            lat.abs() <= 90 &&
            lng.isFinite &&
            lng.abs() <= 180 &&
            description != null) {
          location = (latitude: lat, longitude: lng, description: description);
        } else if (requireExact || locations.isNotEmpty || _current?.location != null) {
          _publish(_current == null ? null : _withLocation(_current!, null));
          await _purgeExact();
        }
      }
    }
    _publish(
      AssignedCase(
        id: summary.caseId,
        need: need,
        priority: priority,
        stage: stage!,
        version: version,
        cell: row?['celda'] as String?,
        expiresAt: deadline,
        location: location,
      ),
    );
    _scheduleReview();
  }

  static DateTime _earlier(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

  void _scheduleReview() {
    _expiryCheck?.cancel();
    final summary = _summary;
    if (summary == null) return;
    var deadline = _current?.expiresAt ?? summary.permit.expiresAt;
    final exact = _exact;
    if (exact != null) deadline = _earlier(deadline, exact.permit.expiresAt);
    final remaining = deadline.difference(clock());
    const interval = Duration(minutes: 1);
    _expiryCheck = Timer(remaining < interval ? remaining : interval, () => _background(review()));
  }

  static AssignedCase _withLocation(AssignedCase value, AssignedCaseLocation? location) =>
      AssignedCase(
        id: value.id,
        need: value.need,
        priority: value.priority,
        stage: value.stage,
        version: value.version,
        cell: value.cell,
        expiresAt: value.expiresAt,
        location: location,
      );

  void _publish(AssignedCase? next) {
    final previous = _current;
    if (previous?.id == next?.id &&
        previous?.version == next?.version &&
        previous?.stage == next?.stage &&
        previous?.cell == next?.cell &&
        previous?.need == next?.need &&
        previous?.priority == next?.priority &&
        previous?.expiresAt == next?.expiresAt &&
        previous?.location == next?.location) {
      return;
    }
    _current = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  Future<void> _purge() async {
    _publish(null);
    _expiryCheck?.cancel();
    await _purgeExact();
    final summary = _summary;
    _summary = null;
    if (summary == null) {
      await LocalSyncDatabase.discard(path: path, store: store, accountId: _scope(accountId));
    } else {
      await summary.stop();
      await summary.local.wipe();
    }
  }

  Future<void> _discardExact() => LocalSyncDatabase.discard(
    path: _exactPath(path),
    store: store,
    accountId: _exactScope(accountId),
  );

  Future<void> _purgeExact() async {
    final exact = _exact;
    _exact = null;
    if (exact == null) {
      await _discardExact();
    } else {
      await exact.stop();
      await exact.local.wipe();
    }
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

class _CaseFeed {
  _CaseFeed(this.local, this.caseId, this.permit);
  final LocalSyncDatabase local;
  final String caseId;
  final AssignedCasePermit permit;
  StreamSubscription<Object?>? rows;
  SyncStreamSubscription? subscription;

  Future<void> stop() async {
    await rows?.cancel();
    subscription?.unsubscribe();
  }
}
