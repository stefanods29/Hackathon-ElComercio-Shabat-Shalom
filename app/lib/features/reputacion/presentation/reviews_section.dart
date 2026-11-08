import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/features/reputacion/data/providers.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/presentation/report_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class ReviewsSection extends ConsumerStatefulWidget {
  const ReviewsSection({super.key, required this.serviceId, this.isOwnService = false});
  final String serviceId;
  final bool isOwnService;
  @override
  ConsumerState<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends ConsumerState<ReviewsSection> {
  bool _busy = false;
  String? _message;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final reviews = ref.watch(publishedReviewsProvider(widget.serviceId));
    final mine = (ref.watch(myReviewsProvider).value ?? <Review>[]).where(
      (r) => r.serviceId == widget.serviceId,
    );
    final endorsement = (ref.watch(myEndorsementsProvider).value ?? <Endorsement>[])
        .where((e) => e.serviceId == widget.serviceId)
        .firstOrNull;
    final auth = ref.watch(authStateProvider).value;
    final level = ref.watch(practiceModeProvider).value == true
        ? ref.watch(effectiveSessionProvider).trustLevel
        : auth is SignedIn
        ? auth.user.trustLevel
        : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(t.reviewsTitle, style: Theme.of(context).textTheme.titleLarge),
        if (!widget.isOwnService)
          FilledButton(
            onPressed: () => context.push('/servicios/${widget.serviceId}/resena'),
            child: Text(mine.isEmpty ? t.writeReview : t.openPreviousReview),
          ),
        if (!widget.isOwnService)
          OutlinedButton.icon(
            icon: Icon(endorsement == null ? Icons.thumb_up_outlined : Icons.thumb_up),
            label: Text(endorsement == null ? t.endorsementAction : t.withdrawEndorsement),
            onPressed: _busy
                ? null
                : () async {
                    setState(() {
                      _busy = true;
                      _message = null;
                    });
                    try {
                      final repository = ref.read(reputationRepositoryProvider);
                      if (endorsement == null) {
                        await repository.giveEndorsement(widget.serviceId);
                      } else {
                        await repository.withdrawEndorsement(widget.serviceId);
                      }
                      if (mounted) {
                        setState(
                          () => _message = endorsement == null && level < 2
                              ? t.endorsementRecorded
                              : t.statusSavedOnPhone,
                        );
                      }
                    } catch (_) {
                      if (mounted) setState(() => _message = t.actionFailed);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          ),
        Text(t.endorsementHelp),
        if (endorsement != null) ...[
          Text(t.endorsementGiven),
          SubmissionStatusChip(status: endorsement.submissionStatus),
        ],
        if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
        for (final review in mine) ReviewCard(review: review),
        reviews.when(
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty) Text(t.noReviews),
              for (final r in items.where((r) => !mine.any((m) => m.id == r.id)))
                ReviewCard(review: r),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(t.actionFailed),
        ),
      ],
    );
  }
}

class ReviewCard extends ConsumerWidget {
  const ReviewCard({super.key, required this.review});
  final Review review;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (review.isMine) Text(t.myReview, style: Theme.of(context).textTheme.titleMedium),
            Text(t.starsLabel(review.rating)),
            if (review.comment != null) Text(review.comment!),
            if (review.isMine) ...[
              Text(switch (review.status) {
                ReviewStatus.inReview => t.reviewInReview,
                ReviewStatus.published => t.reviewsTitle,
                ReviewStatus.hidden => t.reviewHidden,
              }),
              SubmissionStatusChip(status: review.submissionStatus),
            ],
            if (!ref.watch(imagesEnabledProvider) && review.photos.isNotEmpty)
              Text(t.emergencyImagesHidden),
            for (final photo
                in ref.watch(imagesEnabledProvider) ? review.photos : <ReviewPhoto>[]) ...[
              Image.network(
                photo.urlFor(ref.watch(environmentProvider).cdnBaseUrl).toString(),
                semanticLabel: t.reviewPhoto,
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    Icon(Icons.broken_image_outlined, semanticLabel: t.reviewPhoto),
              ),
              ReportButton(content: ReportedContent.photo, contentId: photo.id),
            ],
            ReportButton(content: ReportedContent.review, contentId: review.id),
          ],
        ),
      ),
    );
  }
}

class MyReviewsPage extends ConsumerWidget {
  const MyReviewsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.myReview)),
      body: ref
          .watch(myReviewsProvider)
          .when(
            data: (items) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (items.isEmpty) Text(t.noReviews),
                for (final review in items) ReviewCard(review: review),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(child: Text(t.actionFailed)),
          ),
    );
  }
}
