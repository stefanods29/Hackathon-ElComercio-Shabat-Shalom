import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/reputacion/data/in_memory_reputation_repository.dart';
import 'package:vecinal/features/reputacion/data/providers.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/presentation/report_button.dart';
import 'package:vecinal/features/reputacion/presentation/review_page.dart';
import 'package:vecinal/features/reputacion/presentation/reviews_section.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class TestPhotos implements PhotoPicker {
  TestPhotos({this.uploaded = true});
  final bool uploaded;
  @override
  Future<List<SelectedPhoto>> pick(int remaining) async => List.generate(
    remaining,
    (n) => SelectedPhoto(
      path: '/fixture/$n.jpg',
      name: '$n.jpg',
      uploadedFileId: uploaded ? 'fixture-$n' : null,
    ),
  );
}

class DeniedDictation implements CommentDictation {
  @override
  Future<bool> start(void Function(String) words, void Function() failure) async => false;
  @override
  Future<void> stop() async {}
}

class FailedReports extends InMemoryReputationRepository {
  @override
  Future<Submission> report(NewReport report) async => throw StateError('offline storage failure');
}

Widget reputationHost(
  Widget child,
  InMemoryReputationRepository repository, {
  PhotoPicker? picker,
}) => ProviderScope(
  overrides: [
    reputationRepositoryProvider.overrideWithValue(repository),
    photoPickerProvider.overrideWithValue(picker ?? TestPhotos()),
    commentDictationProvider.overrideWithValue(DeniedDictation()),
  ],
  child: MaterialApp(
    theme: AccessibleTheme.light(),
    locale: const Locale('es'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: child,
  ),
);

void main() {
  testWidgets('estrellas, tres fotos del doble, cola local y En revisión', (tester) async {
    final repository = InMemoryReputationRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(reputationHost(const ReviewPage(serviceId: 'service'), repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('4 de 5 estrellas'));
    await tester.enterText(find.byType(TextField), 'Buen trabajo');
    await tester.tap(find.text('Agregar fotos'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Foto seleccionada 3'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Foto seleccionada 3'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Guardar reseña'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Guardar reseña'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar reseña'));
    await tester.pumpAndSettle();
    expect(find.text('En revisión'), findsOneWidget);
    expect(find.text('Guardado en tu celular'), findsOneWidget);
    expect((await repository.watchMyReviews().first).single.rating, 4);
    expect(repository.submissions.single.kind, SubmissionKind.writeReview);
  });
  testWidgets('seleccionar fotos locales no finge subida y permite enviar sin fotos', (
    tester,
  ) async {
    final repository = InMemoryReputationRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      reputationHost(
        const ReviewPage(serviceId: 'service'),
        repository,
        picker: TestPhotos(uploaded: false),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar fotos'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guardar reseña'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar reseña'));
    await tester.pumpAndSettle();
    expect(repository.submissions, isEmpty);
    expect(find.textContaining('La subida todavía no está disponible'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Enviar sin fotos'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Enviar sin fotos'));
    await tester.pumpAndSettle();
    expect(repository.submissions, hasLength(1));
  });
  testWidgets('dictado rechazado explica permiso y conserva escritura', (tester) async {
    final repository = InMemoryReputationRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(reputationHost(const ReviewPage(serviceId: 'service'), repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dictar comentario'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Puedes escribir el comentario'), findsOneWidget);
  });
  for (final content in [
    ReportedContent.post,
    ReportedContent.service,
    ReportedContent.review,
    ReportedContent.photo,
  ]) {
    testWidgets('denuncia ${content.name} con motivo y estado real de cola', (tester) async {
      final repository = InMemoryReputationRepository();
      addTearDown(repository.close);
      await tester.pumpWidget(
        reputationHost(
          Scaffold(
            body: ReportButton(content: content, contentId: 'content'),
          ),
          repository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Denunciar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Datos personales'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Denunciar'));
      await tester.tap(find.widgetWithText(FilledButton, 'Denunciar'));
      await tester.pumpAndSettle();
      expect(find.text('Gracias, lo revisaremos'), findsOneWidget);
      expect(find.text('Guardado en tu celular'), findsOneWidget);
      expect(repository.submissions.single.kind, SubmissionKind.report);
    });
  }
  testWidgets('fallo de denuncia no muestra gracias', (tester) async {
    final repository = FailedReports();
    addTearDown(repository.close);
    await tester.pumpWidget(
      reputationHost(
        const Scaffold(
          body: ReportButton(content: ReportedContent.photo, contentId: 'photo'),
        ),
        repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Denunciar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Denunciar'));
    await tester.pumpAndSettle();
    expect(find.text('Gracias, lo revisaremos'), findsNothing);
    expect(find.textContaining('No se pudo completar.'), findsOneWidget);
  });
  testWidgets('Visto Bueno nivel 0 registra y explica nivel 2', (tester) async {
    final repository = InMemoryReputationRepository();
    addTearDown(repository.close);
    await tester.pumpWidget(
      reputationHost(
        const Scaffold(
          body: SingleChildScrollView(child: ReviewsSection(serviceId: 'service')),
        ),
        repository,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dar Visto Bueno'));
    await tester.pumpAndSettle();
    expect(find.text('Ya diste tu Visto Bueno'), findsOneWidget);
    expect(find.textContaining('Contará cuando seas vecino verificado'), findsOneWidget);
    expect(find.textContaining('Solo cuenta desde el nivel 2'), findsOneWidget);
  });
}
