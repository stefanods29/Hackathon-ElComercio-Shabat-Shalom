import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/storage/account_data_purge.dart';
import 'package:vecinal/core/storage/pending_photo_purger.dart';

class RecordingPhotoPurger implements PendingPhotoPurger {
  RecordingPhotoPurger(this.log);

  final List<String> log;

  @override
  Future<void> purge(String accountId) async => log.add('fotos:$accountId');
}

void main() {
  test(
    'las fotos pendientes se borran antes de cerrar la sesión y de borrar los archivos',
    () async {
      final log = <String>[];
      await purgeAccountData(
        'neighbor-1',
        pendingPhotos: RecordingPhotoPurger(log),
        closeSession: () async => log.add('sesión'),
        discardStorage: (id) async => log.add('archivos:$id'),
      );
      expect(log, ['fotos:neighbor-1', 'sesión', 'archivos:neighbor-1']);
    },
  );

  test('si falla el borrado de las fotos no se sigue con la sesión abierta a medias', () async {
    final log = <String>[];
    await expectLater(
      purgeAccountData(
        'neighbor-1',
        pendingPhotos: _FailingPurger(),
        closeSession: () async => log.add('sesión'),
        discardStorage: (id) async => log.add('archivos:$id'),
      ),
      throwsA(isA<StateError>()),
    );
    expect(log, isEmpty);
  });

  test('sin la cola de fotos del Lote C no hay nada que borrar', () async {
    await expectLater(const NoPendingPhotos().purge('neighbor-1'), completes);
  });
}

class _FailingPurger implements PendingPhotoPurger {
  @override
  Future<void> purge(String accountId) async => throw StateError('disco lleno');
}
