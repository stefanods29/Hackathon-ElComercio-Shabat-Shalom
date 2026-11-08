import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/ui/notice_card.dart';
import 'package:vecinal/features/reputacion/presentation/rejection_text.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Bandeja de acciones que el servidor rechazó para siempre ("acciones por revisar").
///
/// Cada elemento muestra qué se intentó, el motivo del servidor y una alternativa
/// según el código de rechazo.
class ActionsToReviewPage extends ConsumerWidget {
  const ActionsToReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final actionsAsync = ref.watch(actionsToReviewProvider);
    final wall = ref.watch(wallProvider).value ?? const <Post>[];

    return actionsAsync.when(
      data: (actions) {
        if (actions.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(texts.actionsToReview)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(texts.noActionsToReview, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(texts.actionsToReview)),
          body: ListView.builder(
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              final matching = wall.where((p) => p.id == action.resourceId);
              final post = matching.firstOrNull;
              return _ReviewItem(action: action, post: post);
            },
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(body: Center(child: Text('$error'))),
    );
  }
}

class _ReviewItem extends ConsumerWidget {
  const _ReviewItem({required this.action, required this.post});

  final Submission action;
  final Post? post;

  String _alternativeText(AppLocalizations texts, String code) {
    switch (code) {
      case 'favor_no_disponible':
        return texts.favorUnavailableAlternative;
      case 'conflicto_de_version':
        return texts.conflictVersionAlternative;
      case 'nivel_de_confianza_insuficiente':
        return texts.insufficientTrustAlternative;
      case 'fuera_de_tu_zona':
        return texts.outsideZoneAlternative;
      default:
        return pilotRejectionText(texts, code);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final reason = action.rejectionReason;
    if (reason == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post != null)
              Text(
                '${post!.type.apiValue.toUpperCase()} · ${post!.category}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              post?.title ??
                  switch (action.kind) {
                    SubmissionKind.publish => texts.publishAction,
                    SubmissionKind.takeFavor => texts.takeFavorAction,
                    SubmissionKind.publishService => texts.offerService,
                    SubmissionKind.updateService => texts.editService,
                    SubmissionKind.withdrawService => texts.withdrawService,
                    SubmissionKind.upsertProvider => texts.providerTitle,
                    SubmissionKind.writeReview => texts.writeReview,
                    SubmissionKind.giveEndorsement ||
                    SubmissionKind.withdrawEndorsement => texts.endorsementAction,
                    SubmissionKind.report => texts.reportAction,
                    SubmissionKind.helpRequest => texts.emergencyHelpRequestTitle,
                  },
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            NoticeCard(
              icon: Icons.error_outline,
              title: reason.title,
              detail: reason.detail ?? '',
              background: Theme.of(context).colorScheme.errorContainer,
              foreground: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(height: 12),
            Text(
              action.kind != SubmissionKind.publish && action.kind != SubmissionKind.takeFavor
                  ? pilotRejectionText(texts, reason.code)
                  : _alternativeText(texts, reason.code),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (reason.code == 'resena_duplicada')
              TextButton(
                onPressed: () => context.push('/cuenta/mis-resenas'),
                child: Text(texts.openPreviousReview),
              ),
            if (reason.code == 'favor_no_disponible') ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.home),
                  label: Text(texts.goToWall),
                  onPressed: () => context.go(Routes.home),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
