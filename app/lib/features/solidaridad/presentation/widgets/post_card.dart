import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/notice_card.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/compartir/presentation/share_post_button.dart';
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
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(Routes.postDetail.replaceFirst(':id', post.id)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypePill(type: post.type),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        post.category,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      timeAgo(post.createdAt, ref.watch(clockProvider)(), texts),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(post.title, style: theme.textTheme.titleLarge),
                if (post.submissionStatus == SubmissionStatus.savedOnPhone) ...[
                  const SizedBox(height: 12),
                  NoticeCard(
                    icon: Icons.cloud_off,
                    title: texts.statusSavedOnPhone,
                    detail: texts.statusSavedOnPhoneDetail,
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    SubmissionStatusChip(status: post.submissionStatus),
                    const Spacer(),
                    SharePostButton(post: post),
                  ],
                ),
                if (canTake) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.volunteer_activism_outlined),
                      onPressed: () => _take(context, ref),
                      label: Text(texts.takeFavorAction),
                    ),
                  ),
                ],
              ],
            ),
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

/// Type of favor as a soft pill: icon and text, the color only reinforces it.
class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});
  final PostType type;

  @override
  Widget build(BuildContext context) {
    final (icon, background, foreground) = switch (type) {
      PostType.need => (
        Icons.pan_tool_alt_outlined,
        const Color(0xFFFFF1CC),
        const Color(0xFF5B3B00),
      ),
      PostType.offer || PostType.donate => (
        Icons.volunteer_activism_outlined,
        const Color(0xFFD5F2EE),
        const Color(0xFF064E47),
      ),
      PostType.lend || PostType.exchange => (
        Icons.handshake_outlined,
        const Color(0xFFE3EAF3),
        const Color(0xFF1E3A5F),
      ),
      PostType.ride => (
        Icons.directions_car_outlined,
        const Color(0xFFEDE9FE),
        const Color(0xFF4C1D95),
      ),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              type.apiValue.toUpperCase(),
              style: TextStyle(
                color: foreground,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
