import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/domain/photo_ports.dart';

final _uuid = RegExp(r'^[0-9a-fA-F-]{36}$');

/// Metadata lives in secure storage; files use authenticated AES-GCM with an owner-scoped key.
class EncryptedPhotoLibrary implements PhotoLibrary {
  EncryptedPhotoLibrary({required this.directory, required this.store});
  final Directory directory;
  final SecureStore store;
  final _cipher = AesGcm.with256bits();
  final _keys = <String, Future<SecretKey>>{};
  void _check(String id) {
    if (!_uuid.hasMatch(id)) throw const PhotoFailure('archivo_invalido', retryable: false);
  }

  Directory _owner(String owner) {
    _check(owner);
    return Directory('${directory.path}/$owner');
  }

  File _file(String owner, String id) {
    _check(id);
    return File('${_owner(owner).path}/$id.enc');
  }

  Future<SecretKey> _key(String owner) => _keys.putIfAbsent(owner, () async {
    final saved = await store.read('media.key.$owner');
    if (saved != null) return SecretKey(base64Decode(saved));
    final key = await _cipher.newSecretKey();
    await store.write('media.key.$owner', base64Encode(await key.extractBytes()));
    return key;
  });
  @override
  Future<List<LocalPhoto>> load(String ownerId) async {
    _check(ownerId);
    final saved = await store.read('media.queue.$ownerId');
    if (saved == null) return [];
    return (jsonDecode(saved) as List)
        .map((item) => LocalPhoto.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((photo) => photo.ownerId == ownerId)
        .toList();
  }

  @override
  Future<void> save(String ownerId, List<LocalPhoto> photos) async {
    _check(ownerId);
    if (photos.any((photo) => photo.ownerId != ownerId)) {
      throw const PhotoFailure('cuenta_distinta', retryable: false);
    }
    await store.write(
      'media.queue.$ownerId',
      jsonEncode(photos.map((photo) => photo.toJson()).toList()),
    );
  }

  @override
  Future<void> putBytes(String ownerId, String photoId, Uint8List bytes) async {
    final target = _file(ownerId, photoId);
    await target.parent.create(recursive: true);
    final encrypted = await _cipher.encrypt(
      bytes,
      secretKey: await _key(ownerId),
      aad: utf8.encode('$ownerId:$photoId'),
    );
    final temporary = File('${target.path}.tmp');
    await temporary.writeAsBytes(encrypted.concatenation(), flush: true);
    await temporary.rename(target.path);
  }

  @override
  Future<Uint8List> readBytes(String ownerId, String photoId) async {
    final bytes = await _file(ownerId, photoId).readAsBytes();
    final box = SecretBox.fromConcatenation(bytes, nonceLength: 12, macLength: 16);
    return Uint8List.fromList(
      await _cipher.decrypt(
        box,
        secretKey: await _key(ownerId),
        aad: utf8.encode('$ownerId:$photoId'),
      ),
    );
  }

  @override
  Future<void> deleteBytes(String ownerId, String photoId) async {
    final file = _file(ownerId, photoId);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> clear(String ownerId) async {
    await _keys.remove(ownerId);
    final folder = _owner(ownerId);
    if (await folder.exists()) await folder.delete(recursive: true);
    await store.delete('media.queue.$ownerId');
    await store.delete('media.key.$ownerId');
  }
}
