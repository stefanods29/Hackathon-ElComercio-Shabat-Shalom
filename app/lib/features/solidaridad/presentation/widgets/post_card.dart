import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/ui/notice_card.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Tarjeta de una publicación del muro con etiqueta semántica completa para
/// el lector de pantalla: tipo, título y estado de envío.
///
/// Ejemplo: "Necesito. Necesito dos bidones de agua para mi mamá. Guardado en tu celular."
class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final canTake = post.isAvailable && post.authorId != session.neighborId;

    // Etiqueta semántica: tipo + título + estado de envío, en español.
    final semanticsLabel =
        '${post.type.apiValue}. ${post.title}. ${_statusText(texts, post.submissionStatus)}';

    return Semantics(
      label: semanticsLabel,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${post.type.apiValue.toUpperCase()} · ${post.category}',
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(post.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              if (post.submissionStatus == SubmissionStatus.savedOnPhone)
                NoticeCard(
                  icon: Icons.cloud_off,
                  title: texts.statusSavedOnPhone,
                  detail: texts.statusSavedOnPhoneDetail,
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SubmissionStatusChip(status: post.submissionStatus),
                  if (canTake)
                    FilledButton(
                      onPressed: () => _take(context, ref),
                      child: Text(texts.takeFavorAction),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusText(AppLocalizations texts, SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.savedOnPhone:
        return texts.statusSavedOnPhone;
      case SubmissionStatus.sent:
        return texts.statusSent;
      case SubmissionStatus.couldNotComplete:
        return texts.statusCouldNotComplete;
    }
  }

  Future<void> _take(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final useCase = TakeFavor(
      ref.read(postRepositoryProvider),
      currentNeighborId: ref.read(sessionProvider).neighborId,
    );
    try {
      await useCase.execute(post);
    } on LocalValidationError catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}
