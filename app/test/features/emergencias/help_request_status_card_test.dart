import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';
import 'package:vecinal/features/emergencias/presentation/own_help_requests.dart';
import 'package:vecinal/l10n/app_localizations.dart';

void main() {
  testWidgets('el pedido pendiente avisa que nadie lo recibió y luego muestra la derivación', (
    tester,
  ) async {
    final submittedAt = DateTime.utc(2026, 11, 8);
    final submission = Submission(
      id: 'command',
      kind: SubmissionKind.helpRequest,
      resourceId: 'request',
      idempotencyKey: 'key',
      createdAt: submittedAt,
    );
    Future<void> show(Iterable<HelpRequestHistoryEntry> history) => tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HelpRequestStatusCard(
            state: OwnHelpRequestState(
              requestId: 'request',
              submission: submission,
              history: history,
            ),
          ),
        ),
      ),
    );

    await show([]);
    await tester.pumpAndSettle();
    const notSent = 'Tu pedido todavía no fue enviado. Nadie lo ha recibido.';
    expect(find.text(notSent), findsOneWidget);
    expect(find.text('Enviado'), findsNothing);
    expect(find.textContaining('116, 105 o 106'), findsOneWidget);

    await show([
      HelpRequestHistoryEntry(
        requestId: 'request',
        version: 4,
        stage: HelpRequestStage.referred,
        occurredAt: submittedAt,
        reason: 'Derivado al servicio oficial',
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text(notSent), findsNothing);
    expect(find.text('Derivado'), findsOneWidget);
    expect(find.text('Derivado al servicio oficial'), findsOneWidget);
    expect(find.textContaining('116, 105 o 106'), findsOneWidget);
  });
}
