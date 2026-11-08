import 'dart:typed_data';
import 'package:vecinal/features/media/domain/local_photo.dart';

abstract interface class PhotoLibrary {
  Future<List<LocalPhoto>> load(String ownerId);
  Future<void> save(String ownerId, List<LocalPhoto> photos);
  Future<void> putBytes(String ownerId, String photoId, Uint8List bytes);
  Future<Uint8List> readBytes(String ownerId, String photoId);
  Future<void> deleteBytes(String ownerId, String photoId);
  Future<void> clear(String ownerId);
}

abstract interface class PhotoPicker {
  Future<Uint8List?> pickSanitized();
}

abstract interface class PhotoApi {
  Future<String> reserve(LocalPhoto photo);
  Future<PhotoUploadPermission> permit(LocalPhoto photo);
  Future<void> confirm(LocalPhoto photo);
  Future<String> state(LocalPhoto photo);
  Future<void> remove(LocalPhoto photo);
}

abstract interface class PhotoTransfer {
  Future<void> initialize();
  Future<void> upload(
    LocalPhoto photo,
    PhotoUploadPermission permission,
    Uint8List bytes,
    void Function(double) onProgress,
  );
  Future<void> cancelOwner(String ownerId);
}

class PhotoFailure implements Exception {
  const PhotoFailure(this.code, {this.retryable = true});
  final String code;
  final bool retryable;
}
