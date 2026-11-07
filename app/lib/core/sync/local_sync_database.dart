import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:powersync/powersync.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_schema.dart';

class LocalSyncDatabase {
  LocalSyncDatabase._(this.database, this._path, this._store, this._accountId);

  final PowerSyncDatabase database;
  final String _path;
  final SecureStore _store;
  final String _accountId;
  bool _closed = false;
  Future<void>? _wiping;

  static Future<LocalSyncDatabase> open({
    required String path,
    required SecureStore store,
    required String accountId,
    Schema schema = localSchema,
  }) async {
    final keyName = 'powersync.database.$accountId';
    var key = await store.read(keyName);
    if (key == null) {
      final random = Random.secure();
      key = base64UrlEncode(List.generate(32, (_) => random.nextInt(256)));
      await store.write(keyName, key);
    }
    final db = PowerSyncDatabase(
      schema: schema,
      path: path,
      encryption: EncryptionOptions(key: key),
    );
    try {
      await db.initialize();
      return LocalSyncDatabase._(db, path, store, accountId);
    } catch (_) {
      await db.close();
      rethrow;
    }
  }

  Future<void> wipe() => _wiping ??= _wipe().whenComplete(() => _wiping = null);

  Future<void> _wipe() async {
    if (!_closed) {
      await database.disconnectAndClear();
      await close();
    }
    await discard(path: _path, store: _store, accountId: _accountId);
  }

  /// Removes an encrypted database that has already been closed.
  static Future<void> discard({
    required String path,
    required SecureStore store,
    required String accountId,
  }) async {
    for (final suffix in ['-wal', '-shm', '-journal', '']) {
      final file = File('$path$suffix');
      if (await file.exists()) await file.delete();
    }
    await store.delete('powersync.database.$accountId');
  }

  Future<void> close() async {
    if (_closed) return;
    await database.close();
    _closed = true;
  }
}
