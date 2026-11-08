import 'dart:io';
import 'dart:typed_data';
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/domain/photo_ports.dart';

class NativePhotoTransfer implements PhotoTransfer {
  NativePhotoTransfer({
    required this.storageOrigin,
    required this.currentOwner,
    FileDownloader? downloader,
  }) : _downloader = downloader ?? FileDownloader();
  final Uri storageOrigin;
  final String? Function() currentOwner;
  final FileDownloader _downloader;
  Future<void>? _started;
  static final _id = RegExp(r'^[0-9a-fA-F-]{36}$');
  final _cancellations = <String, int>{};

  @override
  Future<void> initialize() async {
    try {
      await (_started ??= _initialize());
    } catch (_) {
      _started = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    await _downloader.start(autoCleanDatabase: true);
    final owner = currentOwner();
    final tasks = await _downloader.allTasks();
    await _downloader.cancelTasksWithIds(
      tasks
          .where((task) => task.group.startsWith('media-') && task.group != 'media-$owner')
          .map((task) => task.taskId),
    );
    // A terminated process can leave a temporary plaintext copy after native completion.
    final active = await _downloader.allTasks();
    final base = await getApplicationSupportDirectory();
    final root = Directory('${base.path}/media-transfer');
    if (!await root.exists()) return;
    final retained = active
        .where((task) => task.group == 'media-$owner')
        .map((task) => File('${base.path}/${task.directory}/${task.filename}').absolute.path)
        .toSet();
    await for (final folder in root.list(followLinks: false)) {
      if (folder is! Directory) continue;
      await for (final file in folder.list(followLinks: false)) {
        if (file is File && !retained.contains(file.absolute.path)) await file.delete();
      }
      if (await folder.list().isEmpty) await folder.delete();
    }
  }

  @override
  Future<void> upload(
    LocalPhoto photo,
    PhotoUploadPermission permission,
    Uint8List bytes,
    void Function(double) onProgress,
  ) async {
    final generation = _cancellations[photo.ownerId] ?? 0;
    bool active() =>
        currentOwner() == photo.ownerId && (_cancellations[photo.ownerId] ?? 0) == generation;
    final url = permission.url;
    final localHttp =
        url.scheme == 'http' && ['10.0.2.2', '127.0.0.1', 'localhost'].contains(url.host);
    if (!_id.hasMatch(photo.ownerId) ||
        !_id.hasMatch(photo.id) ||
        (url.scheme != 'https' && !localHttp) ||
        url.origin != storageOrigin.origin ||
        url.userInfo.isNotEmpty ||
        url.hasFragment ||
        !permission.expiresAt.isAfter(DateTime.now())) {
      throw const PhotoFailure('permiso_invalido');
    }
    await initialize();
    if (!active()) throw const PhotoFailure('cuenta_distinta', retryable: false);
    final base = await getApplicationSupportDirectory();
    final relative = 'media-transfer/${photo.ownerId}';
    final file = File('${base.path}/$relative/${photo.id}.jpg');
    try {
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      if (!active()) throw const PhotoFailure('cuenta_distinta', retryable: false);
      await _upload(photo, permission, relative, onProgress, active);
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _upload(
    LocalPhoto photo,
    PhotoUploadPermission permission,
    String relative,
    void Function(double) onProgress,
    bool Function() active,
  ) async {
    final task = UploadTask(
      taskId: 'media-${photo.ownerId}-${photo.id}',
      url: permission.url.toString(),
      filename: '${photo.id}.jpg',
      directory: relative,
      baseDirectory: BaseDirectory.applicationSupport,
      httpRequestMethod: 'PUT',
      post: 'binary',
      headers: permission.headers,
      mimeType: 'image/jpeg',
      group: 'media-${photo.ownerId}',
      retries: 0,
      updates: Updates.statusAndProgress,
    );
    final transfer = await _downloader.transfers.getOrStart(task);
    if (!active()) {
      await transfer.cancel();
      throw const PhotoFailure('cuenta_distinta', retryable: false);
    }
    final progress = transfer.progressUpdates.listen((update) {
      if (update.progress >= 0 && update.progress <= 1) onProgress(update.progress);
    });
    try {
      final result = await transfer.result.timeout(
        const Duration(minutes: 6),
        onTimeout: () async {
          await transfer.cancel();
          throw const PhotoFailure('subida_interrumpida');
        },
      );
      // A committed conditional PUT may have completed before the app restarted. The API verifies its hash.
      if (result.status != TaskStatus.complete && result.responseStatusCode != 412) {
        throw const PhotoFailure('subida_interrumpida');
      }
    } finally {
      await progress.cancel();
    }
  }

  @override
  Future<void> cancelOwner(String ownerId) async {
    if (!_id.hasMatch(ownerId)) throw const PhotoFailure('cuenta_invalida');
    _cancellations[ownerId] = (_cancellations[ownerId] ?? 0) + 1;
    try {
      await initialize();
      final tasks = await _downloader.allTasks(group: 'media-$ownerId');
      await _downloader.cancelTasksWithIds(tasks.map((task) => task.taskId));
    } finally {
      final base = await getApplicationSupportDirectory();
      final folder = Directory('${base.path}/media-transfer/$ownerId');
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  }
}
