import 'dart:async';
import 'package:cryptography/cryptography.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/domain/photo_ports.dart';

/// Durable state transitions are independent of widgets, HTTP and the native task scheduler.
class PhotoQueue {
  PhotoQueue({
    required this.ownerId,
    required this.library,
    required this.picker,
    required this.transfer,
    required this.api,
    required this.onChanged,
  });
  final String ownerId;
  final PhotoLibrary library;
  final PhotoPicker picker;
  final PhotoTransfer transfer;
  final PhotoApi? api;
  final void Function(List<LocalPhoto>) onChanged;
  List<LocalPhoto> _photos = [];
  Future<void> _writes = Future.value();
  bool _syncing = false;
  bool _disposed = false;
  bool _again = false;
  bool _paused = false;
  Future<void>? _cancelling;
  bool get _canSync => !_disposed && !_paused && _cancelling == null;
  List<LocalPhoto> get photos => List.unmodifiable(_photos);

  Future<void> load() async {
    final saved = await library.load(ownerId);
    if (_disposed) return;
    _photos = saved;
    final changed = _paused && _requeueUploading();
    _emit();
    if (changed) await _save();
  }

  void _emit() {
    if (!_disposed) onChanged(photos);
  }

  Future<void> _save() {
    final snapshot = photos;
    final write = _writes.then((_) => library.save(ownerId, snapshot));
    _writes = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }

  LocalPhoto? _find(String id) {
    for (final photo in _photos) {
      if (photo.id == id) return photo;
    }
    return null;
  }

  bool _active(String id) {
    final photo = _find(id);
    return _canSync && photo != null && photo.stage != LocalPhotoStage.removing;
  }

  Future<void> _replace(LocalPhoto photo) async {
    final index = _photos.indexWhere((item) => item.id == photo.id);
    if (_disposed || index < 0) return;
    _photos[index] = photo;
    _emit();
    await _save();
  }

  Future<void> add() async {
    if (_photos.length >= 20) throw const PhotoFailure('limite_de_fotos', retryable: false);
    final bytes = await picker.pickSanitized();
    if (bytes == null || _disposed) return;
    if (bytes.isEmpty || bytes.length > 2097152) {
      throw const PhotoFailure('foto_muy_grande', retryable: false);
    }
    final id = newLocalId();
    final digest = await Sha256().hash(bytes);
    if (_disposed) return;
    final photo = LocalPhoto(
      id: id,
      ownerId: ownerId,
      bytes: bytes.length,
      sha256: digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join(),
      createdAt: DateTime.now(),
      reserveKey: newLocalId(),
      confirmKey: newLocalId(),
      removeKey: newLocalId(),
    );
    await library.putBytes(ownerId, id, bytes);
    if (_disposed) {
      await library.deleteBytes(ownerId, id);
      return;
    }
    _photos = [photo, ..._photos];
    _emit();
    await _save();
    _again = true;
  }

  Future<void> remove(String id) async {
    final photo = _find(id);
    if (photo == null) return;
    if (api == null && !photo.uploaded) {
      await library.deleteBytes(ownerId, id);
      _photos.removeWhere((item) => item.id == id);
      _emit();
      await _save();
      return;
    }
    await _replace(photo.copyWith(stage: LocalPhotoStage.removing));
    await transfer.cancelOwner(ownerId);
    _again = true;
  }

  Future<void> retry(String id) async {
    final photo = _find(id);
    if (photo != null && photo.stage == LocalPhotoStage.failed) {
      await _replace(photo.copyWith(stage: LocalPhotoStage.queued));
    }
  }

  Future<void> setPaused(bool paused) async {
    if (_disposed || _paused == paused) return;
    _paused = paused;
    if (!paused) {
      await _cancelling;
      await sync();
      return;
    }
    if (api == null) return;
    final cancel = _cancelling ??= Future<void>.microtask(() async {
      try {
        await transfer.cancelOwner(ownerId);
      } catch (_) {
        // The paused queue still blocks new transfers if native cancellation fails.
      } finally {
        _cancelling = null;
      }
    });
    if (_requeueUploading()) {
      _emit();
      await _save();
    }
    await cancel;
  }

  bool _requeueUploading() {
    if (!_photos.any((photo) => photo.stage == LocalPhotoStage.uploading)) return false;
    _photos = [
      for (final photo in _photos)
        photo.stage == LocalPhotoStage.uploading
            ? photo.copyWith(stage: LocalPhotoStage.queued, progress: 0)
            : photo,
    ];
    return true;
  }

  Future<void> sync() async {
    if (!_canSync || api == null) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        for (final id in _photos.map((photo) => photo.id).toList()) {
          if (!_canSync) return;
          final found = _find(id);
          if (found == null ||
              found.stage == LocalPhotoStage.ready ||
              found.stage == LocalPhotoStage.failed) {
            continue;
          }
          var photo = found;
          try {
            if (photo.stage == LocalPhotoStage.removing) {
              try {
                await api!.remove(photo);
              } on PhotoFailure catch (failure) {
                if (failure.code != 'recurso_no_encontrado') rethrow;
              }
              if (_disposed) return;
              await library.deleteBytes(ownerId, id);
              if (_disposed) return;
              _photos.removeWhere((item) => item.id == id);
              _emit();
              await _save();
              continue;
            }
            final remote = await api!.reserve(photo);
            if (!_active(id)) continue;
            if (remote == 'rechazado') {
              await _replace(
                photo.copyWith(stage: LocalPhotoStage.failed, failure: 'imagen_rechazada'),
              );
              continue;
            }
            if (remote == 'listo') {
              await _replace(photo.copyWith(stage: LocalPhotoStage.ready, uploaded: true));
              continue;
            }
            if (remote == 'pendiente_subida' && !photo.uploaded) {
              final permission = await api!.permit(photo);
              if (!_active(id)) continue;
              final bytes = await library.readBytes(ownerId, id);
              if (!_active(id)) continue;
              await _replace(photo.copyWith(stage: LocalPhotoStage.uploading));
              if (!_active(id)) continue;
              await transfer.upload(photo, permission, bytes, (progress) {
                if (!_active(id)) return;
                final index = _photos.indexWhere((item) => item.id == id);
                _photos[index] = _photos[index].copyWith(progress: progress);
                _emit();
              });
              if (!_active(id)) continue;
            }
            photo = photo.copyWith(stage: LocalPhotoStage.processing, uploaded: true);
            await _replace(photo);
            if (!_active(id)) continue;
            await api!.confirm(photo);
            if (!_active(id)) continue;
            final state = await api!.state(photo);
            if (!_active(id)) continue;
            await _replace(
              photo.copyWith(
                stage: state == 'listo'
                    ? LocalPhotoStage.ready
                    : state == 'rechazado'
                    ? LocalPhotoStage.failed
                    : LocalPhotoStage.processing,
                failure: state == 'rechazado' ? 'imagen_rechazada' : null,
              ),
            );
          } on PhotoFailure catch (failure) {
            if (!_active(id)) continue;
            await _replace(
              photo.copyWith(
                stage: failure.retryable ? LocalPhotoStage.queued : LocalPhotoStage.failed,
                uploaded: failure.code == 'subida_pendiente' ? false : photo.uploaded,
                failure: failure.code,
              ),
            );
          } catch (_) {
            if (_active(id)) {
              await _replace(
                photo.copyWith(stage: LocalPhotoStage.queued, failure: 'no_se_pudo_completar'),
              );
            }
          }
        }
      } while (_again && _canSync);
    } finally {
      _syncing = false;
    }
  }

  Future<void> signOut() async {
    _disposed = true;
    try {
      await transfer.cancelOwner(ownerId);
    } finally {
      await _writes;
      await library.clear(ownerId);
    }
  }

  void dispose() {
    _disposed = true;
  }
}
