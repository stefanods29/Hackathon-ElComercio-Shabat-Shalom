import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry/sentry.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/mode/app_mode.dart';
import 'package:vecinal/core/observability/private_telemetry.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/features/media/application/photo_queue.dart';
import 'package:vecinal/features/media/data/api_photo_client.dart';
import 'package:vecinal/features/media/data/encrypted_photo_library.dart';
import 'package:vecinal/features/media/data/providers.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/domain/photo_ports.dart';

const owner = '01970000-0000-7000-8000-0000000000a1';
const other = '01970000-0000-7000-8000-0000000000b1';
const photoId = '01970000-0000-7000-8000-00000000f001';

class FakeLibrary implements PhotoLibrary {
  final records = <String, List<LocalPhoto>>{};
  final bytes = <String, Uint8List>{};
  @override
  Future<List<LocalPhoto>> load(String ownerId) async => [...?records[ownerId]];
  @override
  Future<void> save(String ownerId, List<LocalPhoto> photos) async {
    records[ownerId] = [...photos];
  }

  @override
  Future<void> putBytes(String ownerId, String photoId, Uint8List value) async {
    bytes['$ownerId/$photoId'] = value;
  }

  @override
  Future<Uint8List> readBytes(String ownerId, String photoId) async => bytes['$ownerId/$photoId']!;
  @override
  Future<void> deleteBytes(String ownerId, String photoId) async {
    bytes.remove('$ownerId/$photoId');
  }

  @override
  Future<void> clear(String ownerId) async {
    records.remove(ownerId);
    bytes.removeWhere((key, _) => key.startsWith('$ownerId/'));
  }
}

class FakePicker implements PhotoPicker {
  Uint8List? result = Uint8List.fromList([1, 2, 3]);
  @override
  Future<Uint8List?> pickSanitized() async => result;
}

class FakeTransfer implements PhotoTransfer {
  int uploads = 0;
  int cancellations = 0;
  bool failCancellation = false;
  Completer<void>? uploadGate;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> upload(
    LocalPhoto photo,
    PhotoUploadPermission permission,
    Uint8List bytes,
    void Function(double) onProgress,
  ) async {
    uploads++;
    onProgress(.5);
    await uploadGate?.future;
    onProgress(1);
  }

  @override
  Future<void> cancelOwner(String ownerId) async {
    cancellations++;
    uploadGate?.completeError(const PhotoFailure('subida_interrumpida'));
    uploadGate = null;
    if (failCancellation) throw const PhotoFailure('subida_interrumpida');
  }
}

class FakeApi implements PhotoApi {
  String remote = 'pendiente_subida';
  bool online = true;
  bool failConfirm = false;
  Completer<void>? removeGate;
  final confirmKeys = <String>[];
  void check() {
    if (!online) throw const PhotoFailure('sin_conexion');
  }

  @override
  Future<String> reserve(LocalPhoto photo) async {
    check();
    return remote;
  }

  @override
  Future<PhotoUploadPermission> permit(LocalPhoto photo) async => PhotoUploadPermission(
    url: Uri.parse('https://storage.example/upload'),
    headers: {},
    expiresAt: DateTime.now().add(const Duration(minutes: 5)),
  );
  @override
  Future<void> confirm(LocalPhoto photo) async {
    check();
    confirmKeys.add(photo.confirmKey);
    remote = 'listo';
    if (failConfirm) {
      failConfirm = false;
      throw const PhotoFailure('sin_conexion');
    }
  }

  @override
  Future<String> state(LocalPhoto photo) async {
    check();
    return remote;
  }

  @override
  Future<void> remove(LocalPhoto photo) async {
    check();
    await removeGate?.future;
    remote = 'eliminado';
  }
}

void main() {
  group('cola durable de fotos', () {
    late FakeLibrary library;
    late FakePicker picker;
    late FakeTransfer transfer;
    late FakeApi api;
    PhotoQueue queue({bool authenticated = true, String account = owner}) => PhotoQueue(
      ownerId: account,
      library: library,
      picker: picker,
      transfer: transfer,
      api: authenticated ? api : null,
      onChanged: (_) {},
    );
    setUp(() {
      library = FakeLibrary();
      picker = FakePicker();
      transfer = FakeTransfer();
      api = FakeApi();
    });
    test('sin sesión conserva el borrador y su huella, sin transferir', () async {
      final service = queue(authenticated: false);
      await service.load();
      await service.add();
      await service.sync();
      expect(service.photos.single.stage, LocalPhotoStage.queued);
      expect(service.photos.single.sha256.length, 64);
      expect(transfer.uploads, 0);
      service.dispose();
      final restarted = queue(authenticated: false);
      await restarted.load();
      expect(restarted.photos.single.id, service.photos.single.id);
      final second = queue(account: other);
      await second.load();
      expect(second.photos, isEmpty);
    });
    test('la caída de red no pierde el archivo y se recupera con una sola subida', () async {
      api.online = false;
      final service = queue();
      await service.load();
      await service.add();
      await service.sync();
      expect(service.photos.single.stage, LocalPhotoStage.queued);
      expect(transfer.uploads, 0);
      api.online = true;
      await service.sync();
      expect(service.photos.single.stage, LocalPhotoStage.ready);
      expect(transfer.uploads, 1);
      await service.sync();
      expect(transfer.uploads, 1);
    });
    test('pausar cancela una subida en curso y la reanuda con la misma identidad', () async {
      final service = queue();
      await service.load();
      await service.add();
      final draft = service.photos.single;
      transfer.uploadGate = Completer<void>();
      final pending = service.sync();
      await Future<void>.delayed(Duration.zero);
      expect(service.photos.single.stage, LocalPhotoStage.uploading);

      await service.setPaused(true);
      await pending;
      expect(transfer.cancellations, 1);
      expect(service.photos.single.stage, LocalPhotoStage.queued);
      expect(service.photos.single.id, draft.id);
      expect(service.photos.single.reserveKey, draft.reserveKey);
      await service.sync();
      expect(transfer.uploads, 1);
      expect(api.confirmKeys, isEmpty);

      await service.setPaused(false);
      expect(service.photos.single.stage, LocalPhotoStage.ready);
      expect(transfer.uploads, 2);
      expect(api.confirmKeys, [draft.confirmKey]);
    });
    test('reiniciar tras perder la confirmación no repite los bytes', () async {
      api.failConfirm = true;
      final service = queue();
      await service.load();
      await service.add();
      await service.sync();
      expect(transfer.uploads, 1);
      service.dispose();
      final restarted = queue();
      await restarted.load();
      await restarted.sync();
      expect(restarted.photos.single.stage, LocalPhotoStage.ready);
      expect(transfer.uploads, 1);
    });
    test('una eliminación pendiente sobrevive y se completa al volver la red', () async {
      final service = queue();
      await service.load();
      await service.add();
      await service.sync();
      api.online = false;
      await service.remove(service.photos.single.id);
      await service.sync();
      expect(service.photos.single.stage, LocalPhotoStage.removing);
      api.online = true;
      await service.sync();
      expect(service.photos, isEmpty);
      expect(library.bytes, isEmpty);
    });
    test('cancelar el selector no crea nada y el cierre de sesión purga solo su cuenta', () async {
      final service = queue();
      await service.load();
      picker.result = null;
      await service.add();
      expect(service.photos, isEmpty);
      picker.result = Uint8List.fromList([1]);
      await service.add();
      await library.putBytes(other, photoId, Uint8List.fromList([2]));
      await service.signOut();
      expect(library.records[owner], isNull);
      expect(library.bytes.keys, ['$other/$photoId']);
    });
    test('el cierre de sesión purga el archivo aunque falle la cancelación nativa', () async {
      final service = queue();
      await service.load();
      await service.add();
      transfer.failCancellation = true;
      await expectLater(service.signOut(), throwsA(isA<PhotoFailure>()));
      expect(library.records[owner], isNull);
      expect(library.bytes, isEmpty);
    });
    test('una baja que termina tarde no recrea metadatos después de cerrar sesión', () async {
      final service = queue();
      await service.load();
      await service.add();
      await service.sync();
      await service.remove(service.photos.single.id);
      api.removeGate = Completer<void>();
      final pending = service.sync();
      await Future<void>.delayed(Duration.zero);
      await service.signOut();
      api.removeGate!.complete();
      await pending;
      expect(library.records[owner], isNull);
      expect(library.bytes, isEmpty);
    });
  });
  test('reconectar en modo emergencia no solicita fotos y salir reanuda la cola', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final requests = <String>[];
    server.listen((request) async {
      await request.drain<void>();
      requests.add(request.uri.path);
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"estado":"listo"}');
      await request.response.close();
    });
    final reconnect = StreamController<bool>.broadcast();
    addTearDown(reconnect.close);
    final transfer = FakeTransfer();
    final library = FakeLibrary();
    library.records[owner] = [
      LocalPhoto(
        id: photoId,
        ownerId: owner,
        bytes: 1,
        sha256: '0' * 64,
        createdAt: DateTime.utc(2026, 11, 8),
        reserveKey: 'reserva',
        confirmKey: 'confirmacion',
        removeKey: 'baja',
        stage: LocalPhotoStage.uploading,
      ),
    ];
    final container = ProviderContainer.test(
      overrides: [
        environmentProvider.overrideWithValue(
          AppEnvironment(apiBaseUrl: 'http://127.0.0.1:${server.port}', powersyncUrl: ''),
        ),
        mediaCredentialsProvider.overrideWithValue(
          const MediaCredentials(userId: owner, accessToken: 'credencial-ficticia'),
        ),
        photoLibraryProvider.overrideWith((ref) async => library),
        photoPickerProvider.overrideWithValue(FakePicker()),
        photoTransferProvider.overrideWithValue(transfer),
        photoConnectionProvider.overrideWithValue(reconnect.stream),
      ],
    );
    final mode = container.read(appModeProvider.notifier);
    mode.activateEmergency();
    await container.read(photoControllerProvider.future);
    final controller = container.read(photoControllerProvider.notifier);
    reconnect.add(true);
    await controller.sync();
    await Future<void>.delayed(Duration.zero);
    expect(requests, isEmpty);
    expect(transfer.uploads, 0);
    expect(transfer.cancellations, 1);
    expect(
      container.read(photoControllerProvider).requireValue.single.stage,
      LocalPhotoStage.queued,
    );
    container.read(imagesEnabledProvider.notifier).set(true);
    expect(container.read(imagesEnabledProvider), isFalse);

    final ready = Completer<void>();
    final subscription = container.listen(photoControllerProvider, (_, next) {
      if (next.value?.singleOrNull?.stage == LocalPhotoStage.ready && !ready.isCompleted) {
        ready.complete();
      }
    });
    addTearDown(subscription.close);
    mode.endEvent();
    await ready.future.timeout(const Duration(seconds: 5));
    expect(requests, hasLength(2));
    expect(requests.first, '/v1/archivos');
  });
  test('archivos cifrados resisten alteraciones y sobreviven una nueva instancia', () async {
    final folder = await Directory.systemTemp.createTemp('vecinal-photo-test-');
    final store = InMemorySecureStore();
    try {
      final library = EncryptedPhotoLibrary(directory: folder, store: store);
      final original = Uint8List.fromList(List.generate(200, (index) => index));
      await library.putBytes(owner, photoId, original);
      final file = File('${folder.path}/$owner/$photoId.enc');
      final encrypted = await file.readAsBytes();
      expect(encrypted, isNot(original));
      final restarted = EncryptedPhotoLibrary(directory: folder, store: store);
      expect(await restarted.readBytes(owner, photoId), original);
      encrypted[20] ^= 1;
      await file.writeAsBytes(encrypted);
      await expectLater(restarted.readBytes(owner, photoId), throwsA(anything));
      await library.clear(owner);
      expect(await store.read('media.key.$owner'), isNull);
    } finally {
      if (!folder.absolute.path.startsWith(Directory.systemTemp.absolute.path)) {
        throw StateError('Ruta temporal inesperada');
      }
      await folder.delete(recursive: true);
    }
  });
  test('la API renueva credenciales y nunca envía con la cuenta de otra persona', () async {
    MediaCredentials? credentials = const MediaCredentials(userId: owner, accessToken: 'primero');
    final headers = <String>[];
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (request, handler) {
            headers.add(request.headers['Authorization'] as String);
            handler.resolve(
              Response(
                requestOptions: request,
                statusCode: 200,
                data: {'estado': 'pendiente_subida'},
              ),
            );
          },
        ),
      );
    final photo = LocalPhoto(
      id: photoId,
      ownerId: owner,
      bytes: 1,
      sha256: '0' * 64,
      createdAt: DateTime.now(),
      reserveKey: 'reserva',
      confirmKey: 'confirmacion',
      removeKey: 'baja',
    );
    final api = ApiPhotoClient(dio: dio, getCredentials: () => credentials);
    await api.state(photo);
    credentials = const MediaCredentials(userId: owner, accessToken: 'segundo');
    await api.state(photo);
    credentials = const MediaCredentials(userId: other, accessToken: 'otra-cuenta');
    await expectLater(api.state(photo), throwsA(isA<PhotoFailure>()));
    expect(headers, ['Bearer primero', 'Bearer segundo']);
    dio.close();
  });
  test('Sentry descarta datos de vecinos aunque el SDK los añada al evento', () {
    final event = SentryEvent(
      message: SentryMessage('teléfono privado'),
      user: SentryUser(id: 'vecino'),
      tags: {'token': 'privado'},
      exceptions: [SentryException(type: 'StateError', value: 'ubicación exacta')],
    );
    final serialized = privateAppEvent(event).toJson().toString();
    for (final secret in ['teléfono', 'vecino', 'token', 'ubicación', 'privado']) {
      expect(serialized, isNot(contains(secret)));
    }
    expect(privateAppEvent(event).exceptions!.single.type, 'StateError');
  });
}
