import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/features/compartir/domain/public_share.dart';

void main() {
  const id = '01970000-0000-7000-8000-00000000f001';
  test('el enlace solo lleva el identificador y nunca texto o ubicación', () {
    expect(
      publicPostLink(
        postId: id,
        status: SubmissionStatus.sent,
        publicBaseUrl: 'https://vecinal.example',
      ),
      'https://vecinal.example/publicaciones/$id',
    );
  });
  test('rechaza publicaciones pendientes, destinos externos y enlaces con credenciales', () {
    for (final base in [
      'http://example.com',
      'https://nombre:clave@example.com',
      'https://example.com?token=algo',
      'https://example.com/ruta',
    ]) {
      expect(
        () => publicPostLink(postId: id, status: SubmissionStatus.sent, publicBaseUrl: base),
        throwsA(isA<PublicShareException>()),
      );
    }
    expect(
      () => publicPostLink(
        postId: id,
        status: SubmissionStatus.savedOnPhone,
        publicBaseUrl: 'https://vecinal.example',
      ),
      throwsA(isA<PublicShareException>()),
    );
    expect(
      () => publicPostLink(
        postId: '../privado',
        status: SubmissionStatus.sent,
        publicBaseUrl: 'https://vecinal.example',
      ),
      throwsA(isA<PublicShareException>()),
    );
  });
}
