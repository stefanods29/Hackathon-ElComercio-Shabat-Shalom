import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/mode/app_mode.dart';
import 'package:vecinal/features/media/data/providers.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/domain/photo_ports.dart';
import 'package:vecinal/features/media/presentation/photo_attachment_picker.dart';
import 'package:vecinal/features/media/presentation/photo_library_page.dart';
import 'package:vecinal/features/media/presentation/public_photo.dart';
import 'package:vecinal/l10n/app_localizations.dart';

const _owner = '01970000-0000-7000-8000-0000000000a1';

LocalPhoto _photo(String suffix, LocalPhotoStage stage) => LocalPhoto(
  id: '01970000-0000-7000-8000-00000000f00$suffix',
  ownerId: _owner,
  bytes: 1,
  sha256: '0' * 64,
  createdAt: DateTime.utc(2026),
  reserveKey: 'reserve-$suffix',
  confirmKey: 'confirm-$suffix',
  removeKey: 'remove-$suffix',
  stage: stage,
);

class _SnapshotController extends PhotoController {
  _SnapshotController(this.photos);
  final List<LocalPhoto> photos;
  final removed = <String>[];
  @override
  Future<List<LocalPhoto>> build() async => photos;
  @override
  Future<void> remove(String id) async {
    removed.add(id);
    state = AsyncData(photos.where((photo) => photo.id != id).toList());
  }
}

class _PreviewLibrary implements PhotoLibrary {
  @override
  Future<Uint8List> readBytes(String ownerId, String photoId) async => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aU1cAAAAASUVORK5CYII=',
  );
  @override
  Future<List<LocalPhoto>> load(String ownerId) async => [];
  @override
  Future<void> save(String ownerId, List<LocalPhoto> photos) async {}
  @override
  Future<void> putBytes(String ownerId, String photoId, Uint8List bytes) async {}
  @override
  Future<void> deleteBytes(String ownerId, String photoId) async {}
  @override
  Future<void> clear(String ownerId) async {}
}

Widget _app(Widget child, _SnapshotController controller) => ProviderScope(
  overrides: [
    environmentProvider.overrideWithValue(
      const AppEnvironment(apiBaseUrl: 'http://localhost', powersyncUrl: '', enablePhotos: true),
    ),
    photoControllerProvider.overrideWith(() => controller),
    photoLibraryProvider.overrideWith((ref) async => _PreviewLibrary()),
  ],
  child: MaterialApp(
    locale: const Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

void main() {
  testWidgets('el modo emergencia retira la imagen remota y evita crear otra', (tester) async {
    final container = ProviderContainer.test();
    final mode = container.read(appModeProvider.notifier);
    mode.activateEmergency();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: PublicPhoto(
              url: Uri.parse('https://example.test/foto.jpg'),
              description: 'Foto ficticia',
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsNothing);
    mode.endEvent();
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    mode.activateEmergency();
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la galería explica el modo local y admite letra grande en una pantalla pequeña', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_app(const PhotoLibraryPage(), _SnapshotController([])));
    await tester.pumpAndSettle();
    final texts = AppLocalizations.of(tester.element(find.byType(PhotoLibraryPage)));
    expect(find.text(texts.photosLocalOnly), findsOneWidget);
    await tester.scrollUntilVisible(find.text(texts.photosEmpty), 200);
    expect(find.text(texts.photosEmpty), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el selector muestra solo fotos listas y permite desmarcar al alcanzar el límite', (
    tester,
  ) async {
    final photos = [
      _photo('1', LocalPhotoStage.ready),
      _photo('2', LocalPhotoStage.ready),
      _photo('3', LocalPhotoStage.queued),
    ];
    var selected = <String>[];
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PhotoAttachmentPicker(
              selectedIds: selected,
              maximum: 1,
              onChanged: (ids) => setState(() => selected = ids),
            ),
          ),
        ),
        _SnapshotController(photos),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(selected, [photos.first.id]);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).last).onChanged, isNull);
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    expect(selected, isEmpty);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).last).onChanged,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('eliminar una foto requiere confirmar y cancelar conserva el borrador', (
    tester,
  ) async {
    final controller = _SnapshotController([_photo('1', LocalPhotoStage.failed)]);
    await tester.pumpWidget(_app(const PhotoLibraryPage(), controller));
    await tester.pumpAndSettle();
    final texts = AppLocalizations.of(tester.element(find.byType(PhotoLibraryPage)));
    final deleteButton = find.widgetWithText(TextButton, texts.photosDelete);
    await tester.scrollUntilVisible(deleteButton, 200);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(texts.photosKeep));
    await tester.pumpAndSettle();
    expect(controller.removed, isEmpty);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text(texts.photosDelete)).last,
    );
    await tester.pumpAndSettle();
    expect(controller.removed, [controller.photos.single.id]);
  });
}
