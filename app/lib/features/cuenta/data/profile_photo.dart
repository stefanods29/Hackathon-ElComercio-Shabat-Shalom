import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/media/data/providers.dart';
import 'package:vecinal/features/media/domain/photo_ports.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';

/// The neighbor's profile photo, kept encrypted on this phone with the photo library of their
/// account. The API has no field for a profile photo yet, so neighbors keep seeing the initial.
///
/// The bytes come from the sanitized picker (compressed, without EXIF or GPS). Signing out clears
/// the owner's photo folder and key, which also removes this photo.
class ProfilePhotoStore {
  const ProfilePhotoStore({required this.library, required this.store});
  final PhotoLibrary library;
  final SecureStore store;

  String _pointer(String owner) => 'media.profile.$owner';

  Future<Uint8List?> read(String owner) async {
    final id = await store.read(_pointer(owner));
    if (id == null) return null;
    try {
      return await library.readBytes(owner, id);
    } catch (_) {
      // The folder was cleared (sign-out) or the file is unreadable: forget the stale pointer.
      await store.delete(_pointer(owner));
      return null;
    }
  }

  Future<void> save(String owner, Uint8List bytes) async {
    final previous = await store.read(_pointer(owner));
    final id = newLocalId();
    await library.putBytes(owner, id, bytes);
    await store.write(_pointer(owner), id);
    if (previous != null) await _delete(owner, previous);
  }

  Future<void> remove(String owner) async {
    final id = await store.read(_pointer(owner));
    await store.delete(_pointer(owner));
    if (id != null) await _delete(owner, id);
  }

  Future<void> _delete(String owner, String id) async {
    try {
      await library.deleteBytes(owner, id);
    } catch (_) {
      // Already gone: nothing else points at it.
    }
  }
}

/// Whose photo it is: the practice profile, or the signed-in neighbor.
final profilePhotoOwnerProvider = Provider<String?>((ref) {
  if (ref.watch(practiceModeProvider).value == true) {
    return ref.watch(effectiveSessionProvider).neighborId;
  }
  final auth = ref.watch(authStateProvider).value;
  return auth is SignedIn ? auth.user.neighborId : null;
});

/// Available where photos are: the same switch as "Mis fotos".
final profilePhotoEnabledProvider = Provider<bool>(
  (ref) =>
      ref.watch(environmentProvider).enablePhotos && ref.watch(profilePhotoOwnerProvider) != null,
);

final profilePhotoProvider = AsyncNotifierProvider<ProfilePhotoController, Uint8List?>(
  ProfilePhotoController.new,
);

class ProfilePhotoController extends AsyncNotifier<Uint8List?> {
  Future<ProfilePhotoStore> _store() async => ProfilePhotoStore(
    library: await ref.read(photoLibraryProvider.future),
    store: ref.read(secureStoreProvider),
  );

  @override
  Future<Uint8List?> build() async {
    final owner = ref.watch(profilePhotoOwnerProvider);
    if (owner == null || !ref.watch(profilePhotoEnabledProvider)) return null;
    final library = await ref.watch(photoLibraryProvider.future);
    return ProfilePhotoStore(library: library, store: ref.watch(secureStoreProvider)).read(owner);
  }

  /// Opens the gallery. Returns false when the neighbor closed it without choosing.
  Future<bool> pick() async {
    final owner = ref.read(profilePhotoOwnerProvider);
    if (owner == null || !ref.read(profilePhotoEnabledProvider)) return false;
    final bytes = await ref.read(photoPickerProvider).pickSanitized();
    if (bytes == null) return false;
    await (await _store()).save(owner, bytes);
    state = AsyncData(bytes);
    return true;
  }

  Future<void> remove() async {
    final owner = ref.read(profilePhotoOwnerProvider);
    if (owner == null) return;
    await (await _store()).remove(owner);
    state = const AsyncData(null);
  }
}
