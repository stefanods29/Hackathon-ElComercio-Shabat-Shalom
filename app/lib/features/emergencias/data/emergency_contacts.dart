import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';

class EmergencyContact {
  const EmergencyContact({required this.id, required this.name, required this.phone});
  final String id;
  final String name;
  final String phone;
  static bool validName(String value) => value.trim().isNotEmpty && value.trim().length <= 80;
  static bool validPhone(String value) => RegExp(r'^\+?[0-9]{6,15}$').hasMatch(value);
  Map<String, String> toJson() => {'id': id, 'name': name, 'phone': phone};
}

abstract interface class EmergencyContactsRepository {
  Stream<List<EmergencyContact>> watch();
  Future<void> save(EmergencyContact contact);
  Future<void> remove(String id);
}

/// One vault lives alongside the real authenticated session and uses its SecureStore.
/// Revocation closes writes synchronously, then waits for in-flight work before deletion.
class EmergencyContactVault {
  EmergencyContactVault(this.store);
  final SecureStore store;
  final _repositories = <String, SecureEmergencyContactsRepository>{};
  final _authorized = <String>{};
  bool _closed = false;
  static String keyFor(String accountId) =>
      'personal.emergency-contacts.v1.${Uri.encodeComponent(accountId)}';
  void authorize(String accountId) {
    if (_closed) throw StateError('Vault closed');
    _authorized.add(accountId);
  }

  EmergencyContactsRepository open(String accountId) {
    if (_closed || !_authorized.contains(accountId)) throw StateError('Session closed');
    return _repositories.putIfAbsent(
      accountId,
      () => SecureEmergencyContactsRepository(store, keyFor(accountId)),
    );
  }

  Future<void> purge(String accountId) async {
    _authorized.remove(accountId);
    final repository = _repositories.remove(accountId);
    if (repository != null) {
      await repository.purge();
    } else {
      // Also handles a previous sign-out interrupted before a repository was opened.
      await store.delete(keyFor(accountId));
    }
  }

  /// Stop exposing cached contacts when the app closes; retain encrypted storage.
  Future<void> close() {
    _closed = true;
    _authorized.clear();
    final closing = _repositories.values.map((repository) => repository.close()).toList();
    _repositories.clear();
    return Future.wait(closing).then((_) {});
  }
}

class SecureEmergencyContactsRepository implements EmergencyContactsRepository {
  SecureEmergencyContactsRepository(this.store, this.key);
  final SecureStore store;
  final String key;
  final _changes = StreamController<List<EmergencyContact>>.broadcast();
  List<EmergencyContact> _contacts = [];
  Future<void> _tail = Future.value();
  bool _loaded = false;
  bool _revoked = false;
  Future<void> _queue(Future<void> Function() work) {
    final next = _tail.then((_) => work());
    _tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _ensureOpen() {
    if (_revoked) throw StateError('Session closed');
  }

  Future<void> _load() async {
    _ensureOpen();
    if (_loaded) return;
    final raw = await store.read(key);
    _ensureOpen();
    if (raw != null) {
      final rows = jsonDecode(raw) as List<Object?>;
      final loaded = rows
          .map((row) {
            final map = row as Map<String, Object?>;
            final contact = EmergencyContact(
              id: map['id'] as String,
              name: map['name'] as String,
              phone: map['phone'] as String,
            );
            if (!EmergencyContact.validName(contact.name) ||
                !EmergencyContact.validPhone(contact.phone))
              throw const FormatException('Invalid contact');
            return contact;
          })
          .toList(growable: false);
      _contacts = loaded;
    }
    _loaded = true;
  }

  @override
  Stream<List<EmergencyContact>> watch() {
    if (_revoked) return Stream.value(const []);
    // Subscribe before loading, so an immediate purge cannot leave a stale first value.
    late StreamController<List<EmergencyContact>> output;
    StreamSubscription<List<EmergencyContact>>? subscription;
    output = StreamController<List<EmergencyContact>>(
      onListen: () {
        subscription = _changes.stream.listen(
          output.add,
          onError: output.addError,
          onDone: output.close,
        );
        _queue(() async {
          await _load();
          if (!_revoked && !output.isClosed) output.add(List.unmodifiable(_contacts));
        }).catchError((Object error, StackTrace stack) {
          if (!output.isClosed) output.addError(error, stack);
        });
      },
      onCancel: () => subscription?.cancel(),
    );
    return output.stream;
  }

  @override
  Future<void> save(EmergencyContact contact) {
    _ensureOpen();
    if (!EmergencyContact.validName(contact.name) || !EmergencyContact.validPhone(contact.phone))
      throw ArgumentError('Invalid contact');
    return _queue(() async {
      await _load();
      _ensureOpen();
      final next = [..._contacts.where((c) => c.id != contact.id), contact];
      await store.write(key, jsonEncode(next.map((c) => c.toJson()).toList()));
      _ensureOpen();
      _contacts = next;
      _changes.add(List.unmodifiable(next));
    });
  }

  @override
  Future<void> remove(String id) {
    _ensureOpen();
    return _queue(() async {
      await _load();
      _ensureOpen();
      final next = _contacts.where((c) => c.id != id).toList();
      await store.write(key, jsonEncode(next.map((c) => c.toJson()).toList()));
      _ensureOpen();
      _contacts = next;
      _changes.add(List.unmodifiable(next));
    });
  }

  Future<void> purge() => _stop(delete: true);
  Future<void> close() => _stop(delete: false);
  Future<void> _stop({required bool delete}) {
    _revoked = true;
    _contacts = [];
    if (!_changes.isClosed) _changes.add(const []);
    return _queue(() async {
      try {
        if (delete) await store.delete(key);
      } finally {
        // Do not wait on paused listeners while closing/revoking a session.
        if (!_changes.isClosed) unawaited(_changes.close());
      }
    });
  }
}

class PracticeEmergencyContactsRepository implements EmergencyContactsRepository {
  final _contacts = <EmergencyContact>[];
  final _changes = StreamController<void>.broadcast();
  bool _closed = false;
  void _ensureOpen() {
    if (_closed) throw StateError('Closed');
  }

  @override
  Stream<List<EmergencyContact>> watch() async* {
    yield List.unmodifiable(_contacts);
    await for (final _ in _changes.stream) {
      yield List.unmodifiable(_contacts);
    }
  }

  @override
  Future<void> save(EmergencyContact contact) async {
    _ensureOpen();
    if (!EmergencyContact.validName(contact.name) || !EmergencyContact.validPhone(contact.phone))
      throw ArgumentError('Invalid contact');
    _contacts.removeWhere((c) => c.id == contact.id);
    _contacts.add(contact);
    _changes.add(null);
  }

  @override
  Future<void> remove(String id) async {
    _ensureOpen();
    _contacts.removeWhere((c) => c.id == id);
    _changes.add(null);
  }

  void close() {
    _closed = true;
    _contacts.clear();
    unawaited(_changes.close());
  }
}

/// Real storage is unavailable unless AuthenticatedApp supplies its purge-aware vault.
final emergencyContactVaultProvider = Provider<EmergencyContactVault?>((ref) => null);
final emergencyContactsRepositoryProvider = Provider<EmergencyContactsRepository?>((ref) {
  final scope = ref.watch(emergencyScopeProvider);
  if (scope == null) return null;
  if (scope.practice) {
    final repository = PracticeEmergencyContactsRepository();
    ref.onDispose(repository.close);
    return repository;
  }
  final vault = ref.watch(emergencyContactVaultProvider);
  if (vault == null) return null;
  try {
    return vault.open(scope.accountId);
  } catch (_) {
    return null;
  }
});
final emergencyContactsProvider = StreamProvider<List<EmergencyContact>>((ref) {
  final repository = ref.watch(emergencyContactsRepositoryProvider);
  return repository?.watch() ?? Stream.value(const []);
});
