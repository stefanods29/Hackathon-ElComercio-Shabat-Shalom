import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/features/media/application/photo_queue.dart';
import 'package:vecinal/features/media/data/api_photo_client.dart';
import 'package:vecinal/features/media/data/device_photo_picker.dart';
import 'package:vecinal/features/media/data/encrypted_photo_library.dart';
import 'package:vecinal/features/media/data/native_photo_transfer.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/domain/photo_ports.dart';

/// Lot A supplies credentials from the real session. Demo drafts can never leave the device.
final mediaCredentialsProvider = Provider<MediaCredentials?>((ref) => null);
final photoConnectionProvider = Provider<Stream<bool>>(
  (ref) => Connectivity().onConnectivityChanged.map(
    (values) => !values.contains(ConnectivityResult.none),
  ),
);
final photoLibraryProvider = FutureProvider<PhotoLibrary>((ref) async {
  final store = ref.watch(secureStoreProvider);
  final root = await getApplicationSupportDirectory();
  return EncryptedPhotoLibrary(directory: Directory('${root.path}/media'), store: store);
});
final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());
final photoTransferProvider = Provider<PhotoTransfer>(
  (ref) => NativePhotoTransfer(
    currentOwner: () => ref.read(mediaCredentialsProvider)?.userId,
    networkAllowed: () => ref.read(imagesEnabledProvider),
    storageOrigin: Uri.parse(ref.watch(environmentProvider).mediaStorageOrigin),
  ),
);

final photoControllerProvider = AsyncNotifierProvider<PhotoController, List<LocalPhoto>>(
  PhotoController.new,
);

class PhotoController extends AsyncNotifier<List<LocalPhoto>> {
  PhotoQueue? _queue;
  int _generation = 0;
  @override
  Future<List<LocalPhoto>> build() async {
    final generation = ++_generation;
    final userId = ref.watch(mediaCredentialsProvider.select((value) => value?.userId));
    final localOwner = ref.watch(sessionProvider.select<String>((value) => value.neighborId));
    final String owner = userId ?? localOwner;
    final library = await ref.watch(photoLibraryProvider.future);
    if (!ref.mounted || generation != _generation) return [];
    final environment = ref.read(environmentProvider);
    final dio = Dio(
      BaseOptions(
        baseUrl: environment.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 20),
      ),
    );
    final transfer = ref.read(photoTransferProvider);
    await transfer.initialize();
    if (!ref.mounted || generation != _generation) {
      dio.close();
      return [];
    }
    final queue = PhotoQueue(
      ownerId: owner,
      library: library,
      picker: ref.read(photoPickerProvider),
      transfer: transfer,
      api: userId == null
          ? null
          : ApiPhotoClient(
              dio: dio,
              getCredentials: () =>
                  ref.read(imagesEnabledProvider) ? ref.read(mediaCredentialsProvider) : null,
            ),
      onChanged: (photos) {
        if (ref.mounted && generation == _generation) state = AsyncData(photos);
      },
    );
    _queue = queue;
    ref.listen(imagesEnabledProvider, (_, enabled) {
      unawaited(queue.setPaused(!enabled));
    });
    unawaited(queue.setPaused(!ref.read(imagesEnabledProvider)));
    final subscription = ref.watch(photoConnectionProvider).listen((online) {
      if (online) unawaited(queue.sync());
    });
    final timer = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(queue.sync()));
    ref.onDispose(() {
      queue.dispose();
      timer.cancel();
      unawaited(subscription.cancel());
      dio.close();
    });
    await queue.load();
    unawaited(
      Future<void>.microtask(() {
        if (ref.mounted && generation == _generation) unawaited(queue.sync());
      }),
    );
    return queue.photos;
  }

  Future<void> add() async {
    await _queue?.add();
    unawaited(_queue?.sync() ?? Future.value());
  }

  Future<void> retry(String id) async {
    await _queue?.retry(id);
    unawaited(_queue?.sync() ?? Future.value());
  }

  Future<void> remove(String id) async {
    await _queue?.remove(id);
    unawaited(_queue?.sync() ?? Future.value());
  }

  Future<void> sync() async {
    await _queue?.sync();
  }

  Future<void> signOut() async {
    await _queue?.signOut();
    if (ref.mounted) state = const AsyncData([]);
  }
}
