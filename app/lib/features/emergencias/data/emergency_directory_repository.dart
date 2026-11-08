import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:vecinal/features/emergencias/data/emergency_directory_store.dart';
import 'package:vecinal/features/emergencias/domain/emergency_directory.dart';

enum EmergencyRefreshResult {
  /// A new valid copy replaced the previous one.
  updated,

  /// The published file is the one already on the phone: it was not downloaded again.
  unchanged,

  /// The same zone was checked less than [EmergencyDirectoryRepository.checkEvery] ago.
  skipped,

  /// The index has no file for the zone: the phone shows the bundled backup.
  noDirectoryForZone,

  /// The index or the file failed the hash or the contract: the previous copy stays.
  corrupted,

  /// No connection or the CDN did not answer: the previous copy stays.
  failed,
}

/// Emergency directory of the neighbor's district (Lot A, part 2).
///
/// It downloads `emergencia/indice.json` and the district file from the public CDN without the
/// session token, checks the SHA-256 and the contract before replacing the copy, and checks at most
/// once a day per zone. A failed check is retried on the next one (start or resume).
class EmergencyDirectoryRepository {
  EmergencyDirectoryRepository({
    required this._cdn,
    required this._store,
    required this._loadBackup,
    this._clock = DateTime.now,
    this.checkEvery = const Duration(days: 1),
  });

  static const indexPath = '/emergencia/indice.json';

  static String filePath(String file) => '/emergencia/$file';

  final Dio _cdn;
  final EmergencyDirectoryStore _store;
  final Future<String> Function() _loadBackup;
  final DateTime Function() _clock;
  final Duration checkEvery;
  final _changes = StreamController<void>.broadcast();
  Future<void> _queue = Future.value();
  EmergencyDirectory? _backup;

  /// Last valid downloaded copy; the bundled backup when there is none or it was damaged.
  Future<EmergencyDirectory> current() async {
    final bytes = await _store.readDirectory();
    if (bytes != null) {
      try {
        return decodeEmergencyDirectory(bytes, origin: EmergencyDirectoryOrigin.downloaded);
      } on FormatException {
        // A damaged copy never hides the numbers: the backup takes its place.
      }
    }
    return _backup ??= parseEmergencyDirectory(
      jsonDecode(await _loadBackup()),
      origin: EmergencyDirectoryOrigin.backup,
    );
  }

  /// The current copy now and again after every change.
  Stream<EmergencyDirectory> watch() => Stream.multi((listener) {
    var latest = 0;
    void emit() {
      final ticket = ++latest;
      unawaited(
        current().then(
          (directory) {
            if (ticket == latest) listener.add(directory);
          },
          onError: (Object error, StackTrace stack) {
            if (ticket == latest) listener.addError(error, stack);
          },
        ),
      );
    }

    final updates = _changes.stream.listen((_) => emit());
    listener.onCancel = updates.cancel;
    emit();
  });

  /// Looks for a new copy for [zoneId]. Without [force], at most once per [checkEvery].
  Future<EmergencyRefreshResult> refresh({required String zoneId, bool force = false}) =>
      _serialize(() => _refresh(zoneId, force));

  /// Forgets the zone of the last check, for account deletion. The public copy stays.
  Future<void> forgetLastCheck() => _serialize(_store.deleteLastCheck);

  Future<void> close() => _changes.close();

  Future<EmergencyRefreshResult> _refresh(String zoneId, bool force) async {
    final now = _clock();
    if (!force) {
      final last = await _store.readLastCheck();
      if (last != null &&
          last.zoneId == zoneId &&
          !now.isBefore(last.checkedAt) &&
          now.difference(last.checkedAt) < checkEvery) {
        return EmergencyRefreshResult.skipped;
      }
    }

    final indexBytes = await _download(indexPath);
    if (indexBytes == null) return EmergencyRefreshResult.failed;
    final index = _decodeIndex(indexBytes);
    if (index == null) return EmergencyRefreshResult.corrupted;

    final district = index.forZone(zoneId);
    if (district == null) {
      // A copy of another district would show wrong meeting points: the national backup is safer.
      await _store.deleteDirectory();
      await _recordCheck(zoneId, now);
      _changes.add(null);
      return EmergencyRefreshResult.noDirectoryForZone;
    }

    final stored = await _store.readDirectory();
    if (stored != null && _hash(stored) == district.sha256) {
      await _recordCheck(zoneId, now);
      return EmergencyRefreshResult.unchanged;
    }

    final bytes = await _download(filePath(district.file));
    if (bytes == null) return EmergencyRefreshResult.failed;
    if (bytes.length != district.bytes || _hash(bytes) != district.sha256) {
      return EmergencyRefreshResult.corrupted;
    }
    try {
      final directory = decodeEmergencyDirectory(
        bytes,
        origin: EmergencyDirectoryOrigin.downloaded,
      );
      if (directory.version != district.version) return EmergencyRefreshResult.corrupted;
    } on FormatException {
      return EmergencyRefreshResult.corrupted;
    }
    await _store.saveDirectory(Uint8List.fromList(bytes));
    await _recordCheck(zoneId, now);
    _changes.add(null);
    return EmergencyRefreshResult.updated;
  }

  /// Public file without the session token or any identifier of the neighbor.
  Future<List<int>?> _download(String path) async {
    try {
      final response = await _cdn.get<List<int>>(path);
      return response.statusCode == 200 ? response.data : null;
    } on DioException {
      return null;
    }
  }

  static EmergencyIndex? _decodeIndex(List<int> bytes) {
    try {
      return decodeEmergencyIndex(bytes);
    } on FormatException {
      return null;
    }
  }

  Future<void> _recordCheck(String zoneId, DateTime now) =>
      _store.saveLastCheck(EmergencyCheck(zoneId: zoneId, checkedAt: now));

  static String _hash(List<int> bytes) => sha256.convert(bytes).toString();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }
}
