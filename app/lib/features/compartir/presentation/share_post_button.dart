import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/features/compartir/data/share_service.dart';
import 'package:vecinal/features/compartir/domain/public_share.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class SharePostButton extends ConsumerWidget {
  const SharePostButton({super.key, required this.post});
  final Post post;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    return OutlinedButton.icon(
      icon: const Icon(Icons.share_outlined),
      label: Text(texts.shareAction),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final link = publicPostLink(
            postId: post.id,
            status: post.submissionStatus,
            publicBaseUrl: ref.read(environmentProvider).publicAppUrl,
          );
          final box = context.findRenderObject()! as RenderBox;
          await ref
              .read(shareServiceProvider)
              .share(texts.sharePublicPost(link), box.localToGlobal(Offset.zero) & box.size);
          // The share sheet cannot confirm that another person received a message.
        } on PublicShareException catch (error) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                error.reason == PublicShareFailure.notSent
                    ? texts.shareNotSent
                    : texts.shareUnavailable,
              ),
            ),
          );
        } catch (_) {
          messenger.showSnackBar(SnackBar(content: Text(texts.shareUnavailable)));
        }
      },
    );
  }
}
