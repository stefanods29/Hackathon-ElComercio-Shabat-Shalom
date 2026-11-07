import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';

void main() {
  const rejection = RejectionReason(code: 'favor_no_disponible', title: 'Conflicto');

  group('nextStatus', () {
    test('aceptado → enviado; rechazado → no se pudo completar; transitorio → sigue en el celular', () {
      expect(nextStatus(SubmissionStatus.savedOnPhone, const Accepted()), SubmissionStatus.sent);
      expect(
        nextStatus(SubmissionStatus.savedOnPhone, const Rejected(rejection)),
        SubmissionStatus.couldNotComplete,
      );
      expect(
        nextStatus(SubmissionStatus.savedOnPhone, const TransientFailure('sin red')),
        SubmissionStatus.savedOnPhone,
      );
    });

    test('un envío final no admite más intentos', () {
      expect(
        () => nextStatus(SubmissionStatus.sent, const Accepted()),
        throwsA(isA<StateError>()),
      );
      expect(
        () => nextStatus(SubmissionStatus.couldNotComplete, const TransientFailure('x')),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Submission.recordAttempt', () {
    final createdAt = DateTime.utc(2026, 11, 6, 15);
    final submission = Submission(
      id: 'envio-1',
      kind: SubmissionKind.takeFavor,
      resourceId: 'publicacion-1',
      idempotencyKey: 'clave-1',
      createdAt: createdAt,
    );

    test('cuenta intentos y conserva la misma clave de idempotencia en cada reintento', () {
      final first = submission.recordAttempt(const TransientFailure('sin red'), createdAt);
      final second = first.recordAttempt(
        const Accepted(),
        createdAt.add(const Duration(minutes: 1)),
      );
      expect(first.attempts, 1);
      expect(second.attempts, 2);
      expect(second.status, SubmissionStatus.sent);
      expect(second.sentAt, createdAt.add(const Duration(minutes: 1)));
      expect(second.idempotencyKey, 'clave-1');
    });

    test('guarda el motivo del rechazo para "acciones por revisar"', () {
      final rejected = submission.recordAttempt(const Rejected(rejection), createdAt);
      expect(rejected.status, SubmissionStatus.couldNotComplete);
      expect(rejected.rejectionReason, rejection);
    });
  });
}
