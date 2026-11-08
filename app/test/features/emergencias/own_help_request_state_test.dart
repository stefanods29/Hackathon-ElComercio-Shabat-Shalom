import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';

void main() {
  for (final stage in [HelpRequestStage.referred, HelpRequestStage.closedWithoutAssistance]) {
    test('recupera el motivo y siguiente paso de ${stage.name} al sincronizar', () {
      const requestId = 'pedido-propio';
      final createdAt = DateTime.utc(2026, 11, 8, 12);
      final draft = Submission(
        id: 'accion-local',
        kind: SubmissionKind.helpRequest,
        resourceId: requestId,
        idempotencyKey: 'clave-local',
        createdAt: createdAt,
      );
      final foreign = HelpRequestHistoryEntry(
        requestId: 'pedido-ajeno',
        version: 10,
        stage: HelpRequestStage.attended,
        occurredAt: createdAt,
      );
      final beforeSync = OwnHelpRequestState(
        requestId: requestId,
        submission: draft,
        history: [foreign],
      );
      expect(beforeSync.savedOnPhone, isTrue);
      expect(beforeSync.received, isFalse);
      expect(beforeSync.history, isEmpty);

      final sent = HelpRequestHistoryEntry(
        requestId: requestId,
        version: 1,
        stage: HelpRequestStage.sent,
        occurredAt: createdAt.add(const Duration(minutes: 1)),
      );
      final finalEntry = HelpRequestHistoryEntry(
        requestId: requestId,
        version: 3,
        stage: stage,
        occurredAt: createdAt.add(const Duration(minutes: 4)),
        reason: 'El caso requiere atención oficial.',
        nextStep: 'Consulta el directorio de emergencia.',
      );
      final afterSync = OwnHelpRequestState(
        requestId: requestId,
        submission: draft,
        history: [finalEntry, foreign, sent],
      );
      expect(afterSync.savedOnPhone, isFalse);
      expect(afterSync.received, isTrue);
      expect(afterSync.sentAt, sent.occurredAt);
      expect(afterSync.history, [sent, finalEntry]);
      expect(afterSync.latest?.stage, stage);
      expect(afterSync.latest?.reason, 'El caso requiere atención oficial.');
      expect(afterSync.latest?.nextStep, 'Consulta el directorio de emergencia.');
    });
  }
}
