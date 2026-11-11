import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/cuenta/data/profile_photo.dart';
import 'package:vecinal/features/cuenta/presentation/profile_page.dart';
import 'package:vecinal/features/media/data/providers.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/domain/photo_ports.dart';
import 'package:vecinal/l10n/app_localizations.dart';

const _owner = '01970000-0000-7000-8000-0000000000b1';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aU1cAAAAASUVORK5CYII=',
);

/// The encrypted library without a disk: one entry per owner and photo.
class _MemoryLibrary implements PhotoLibrary {
  final files = <String, Uint8List>{};
  @override
  Future<List<LocalPhoto>> load(String ownerId) async => [];
  @override
  Future<void> save(String ownerId, List<LocalPhoto> photos) async {}
  @override
  Future<void> putBytes(String ownerId, String photoId, Uint8List bytes) async =>
      files['$ownerId/$photoId'] = bytes;
  @override
  Future<Uint8List> readBytes(String ownerId, String photoId) async =>
      files['$ownerId/$photoId'] ?? (throw StateError('No existe'));
  @override
  Future<void> deleteBytes(String ownerId, String photoId) async =>
      files.remove('$ownerId/$photoId');
  @override
  Future<void> clear(String ownerId) async =>
      files.removeWhere((key, _) => key.startsWith('$ownerId/'));
}

/// The gallery returns this photo, already compressed and without metadata.
class _Picker implements PhotoPicker {
  Uint8List? next;
  @override
  Future<Uint8List?> pickSanitized() async => next;
}

void main() {
  late AppLocalizations t;
  setUpAll(() async => t = await AppLocalizations.delegate.load(const Locale('es')));

  group('ProfilePhotoStore', () {
    test('guarda, reemplaza y quita la foto sin dejar archivos huérfanos', () async {
      final library = _MemoryLibrary();
      final store = ProfilePhotoStore(library: library, store: InMemorySecureStore());
      expect(await store.read(_owner), isNull);
      await store.save(_owner, Uint8List.fromList([1, 2, 3]));
      expect(await store.read(_owner), [1, 2, 3]);
      await store.save(_owner, Uint8List.fromList([4, 5]));
      expect(await store.read(_owner), [4, 5]);
      expect(library.files, hasLength(1));
      await store.remove(_owner);
      expect(await store.read(_owner), isNull);
      expect(library.files, isEmpty);
    });

    test('si se borró la carpeta al cerrar sesión, ya no hay foto', () async {
      final library = _MemoryLibrary();
      final store = ProfilePhotoStore(library: library, store: InMemorySecureStore());
      await store.save(_owner, Uint8List.fromList([1]));
      await library.clear(_owner);
      expect(await store.read(_owner), isNull);
    });
  });

  Future<_MemoryLibrary> show(
    WidgetTester tester, {
    required bool enablePhotos,
    _Picker? picker,
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({'practiceMode': true});
    tester.view.physicalSize = const Size(414, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final library = _MemoryLibrary();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          environmentProvider.overrideWithValue(
            AppEnvironment(
              apiBaseUrl: 'http://localhost',
              powersyncUrl: '',
              enablePhotos: enablePhotos,
            ),
          ),
          photoLibraryProvider.overrideWith((ref) async => library),
          photoPickerProvider.overrideWithValue(picker ?? _Picker()),
          secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        ],
        child: MaterialApp(
          locale: const Locale('es'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const EditProfilePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return library;
  }

  bool showsPhoto(WidgetTester tester) => tester
      .widgetList<CircleAvatar>(find.byType(CircleAvatar))
      .any((avatar) => avatar.backgroundImage != null);

  testWidgets('en Editar perfil se elige, se ve y se quita la foto guardada en el celular', (
    tester,
  ) async {
    final picker = _Picker()..next = _png;
    final library = await show(tester, enablePhotos: true, picker: picker);
    expect(find.text(t.profilePhotoLocalNote), findsOneWidget);
    expect(find.text(t.profilePhotoRemove), findsNothing);
    expect(showsPhoto(tester), isFalse);

    await tester.tap(find.text(t.profilePhotoAdd));
    await tester.pumpAndSettle();
    expect(find.text(t.profilePhotoSaved), findsOneWidget);
    expect(showsPhoto(tester), isTrue);
    expect(find.text(t.profilePhotoChange), findsOneWidget);
    expect(library.files, hasLength(1));

    await tester.tap(find.text(t.profilePhotoRemove));
    await tester.pumpAndSettle();
    expect(showsPhoto(tester), isFalse);
    expect(library.files, isEmpty);
    expect(find.text(t.profilePhotoAdd), findsOneWidget);
  });

  testWidgets('si se cierra la galería sin elegir, no cambia nada', (tester) async {
    final library = await show(tester, enablePhotos: true, picker: _Picker());
    await tester.tap(find.text(t.profilePhotoAdd));
    await tester.pumpAndSettle();
    expect(find.text(t.profilePhotoSaved), findsNothing);
    expect(library.files, isEmpty);
  });

  testWidgets('sin fotos habilitadas no se ofrece la foto de perfil', (tester) async {
    await show(tester, enablePhotos: false);
    expect(find.text(t.profilePhotoAdd), findsNothing);
    expect(find.text(t.profilePhotoLocalNote), findsNothing);
  });

  testWidgets('con texto al 200 % no se desborda y cada botón es grande y tiene nombre', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await show(tester, enablePhotos: true, textScale: 2);
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });
}
