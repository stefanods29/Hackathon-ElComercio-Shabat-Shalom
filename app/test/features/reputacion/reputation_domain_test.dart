import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/features/reputacion/data/in_memory_reputation_repository.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/domain/use_cases.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart';

void main() {
  late InMemoryReputationRepository reputation;

  setUp(() => reputation = InMemoryReputationRepository(ownServiceIds: {'mio'}));
  tearDown(() => reputation.close());

  group('validación de la reseña', () {
    test('las estrellas van de 1 a 5', () async {
      expect(
        () => WriteReview(reputation).execute(const NewReview(serviceId: 'otro', rating: 6)),
        throwsA(isA<LocalValidationError>().having((e) => e.field, 'campo', 'rating')),
      );
    });

    test('se aceptan hasta 3 fotos', () async {
      expect(
        () => WriteReview(reputation).execute(
          const NewReview(serviceId: 'otro', rating: 4, photoFileIds: ['a', 'b', 'c', 'd']),
        ),
        throwsA(isA<LocalValidationError>().having((e) => e.field, 'campo', 'photos')),
      );
      expect(reputation.submissions, isEmpty);
    });

    test('el detalle de una denuncia no pasa de 500 caracteres', () async {
      expect(
        () => ReportContent(reputation).execute(
          NewReport(
            content: ReportedContent.review,
            contentId: 'r1',
            reason: ReportReason.offensive,
            detail: 'x' * 501,
          ),
        ),
        throwsA(isA<LocalValidationError>().having((e) => e.field, 'campo', 'detail')),
      );
    });
  });

  group('reglas de reputación en el celular', () {
    test('nadie se reseña ni se da Visto Bueno a sí mismo', () async {
      expect(
        () => WriteReview(reputation).execute(const NewReview(serviceId: 'mio', rating: 5)),
        throwsA(isA<LocalValidationError>()),
      );
      await expectLater(reputation.giveEndorsement('mio'), throwsA(isA<LocalValidationError>()));
    });

    test('la reseña queda "En revisión" y "Guardado en tu celular", y no se duplica', () async {
      await WriteReview(reputation).execute(const NewReview(serviceId: 'otro', rating: 4));
      final mine = (await reputation.watchMyReviews().first).single;
      expect(mine.status, ReviewStatus.inReview);
      expect(mine.submissionStatus, SubmissionStatus.savedOnPhone);
      expect(
        () => WriteReview(reputation).execute(const NewReview(serviceId: 'otro', rating: 2)),
        throwsA(isA<LocalValidationError>()),
      );
    });

    test('un Visto Bueno rechazado desaparece', () async {
      final submission = await reputation.giveEndorsement('otro');
      expect((await reputation.watchMyEndorsements().first).single.serviceId, 'otro');
      reputation.recordResponse(
        submission.id,
        const Rejected(RejectionReason(code: 'fuera_de_tu_zona', title: 'Zona')),
      );
      expect(await reputation.watchMyEndorsements().first, isEmpty);
    });
  });

  test('la foto se arma con la plantilla pública de la CDN', () {
    const photo = ReviewPhoto(id: 'f1', reviewId: 'r1', fileId: 'archivo-1', order: 0);
    expect(
      photo.urlFor('https://cdn.example.test/').toString(),
      'https://cdn.example.test/media/archivo-1/miniatura.webp',
    );
    expect(
      photo.urlFor('https://cdn.example.test', PhotoVariant.large).toString(),
      'https://cdn.example.test/media/archivo-1/grande.webp',
    );
  });

  test('los estados de la reseña vienen del contrato', () {
    expect(ReviewStatus.fromApi('en_revision'), ReviewStatus.inReview);
    expect(ReviewStatus.fromApi('oculta'), ReviewStatus.hidden);
    expect(() => ReviewStatus.fromApi('borrador'), throwsFormatException);
  });
}
