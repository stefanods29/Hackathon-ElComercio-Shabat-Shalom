import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/reputacion/data/providers.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/domain/use_cases.dart';
import 'package:vecinal/features/reputacion/presentation/reviews_section.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class ReviewPage extends ConsumerStatefulWidget {
  const ReviewPage({super.key, required this.serviceId});
  final String serviceId;
  @override
  ConsumerState<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends ConsumerState<ReviewPage> {
  final _comment = TextEditingController();
  final _photos = <SelectedPhoto>[];
  int _rating = 3;
  bool _busy = false;
  bool _listening = false;
  String? _error;
  String? _commentError;
  CommentDictation? _dictation;
  @override
  void dispose() {
    unawaited(_dictation?.stop());
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save({bool withoutPhotos = false}) async {
    if (_busy) return;
    final t = AppLocalizations.of(context);
    if (_comment.text.trim().length > 2000) {
      setState(() => _commentError = t.commentTooLong);
      return;
    }
    if (!withoutPhotos && _photos.any((p) => p.uploadedFileId == null)) {
      setState(() => _error = t.photosPending);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _commentError = null;
    });
    try {
      await _dictation?.stop();
      await WriteReview(ref.read(reputationRepositoryProvider)).execute(
        NewReview(
          serviceId: widget.serviceId,
          rating: _rating,
          comment: _comment.text,
          photoFileIds: withoutPhotos ? [] : _photos.map((p) => p.uploadedFileId!).toList(),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _error = t.actionFailed);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _listening = false;
        });
      }
    }
  }

  Future<void> _dictate() async {
    final t = AppLocalizations.of(context);
    _dictation = ref.read(commentDictationProvider);
    if (_listening) {
      await _dictation!.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    try {
      final started = await _dictation!.start(
        (words) {
          if (mounted) setState(() => _comment.text = words);
        },
        () {
          if (mounted) {
            setState(() {
              _listening = false;
              _error = t.dictationDenied;
            });
          }
        },
      );
      if (mounted) {
        setState(() {
          _listening = started;
          if (!started) _error = t.dictationDenied;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = t.dictationDenied);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final mine = ref.watch(myReviewsProvider);
    final service = ref.watch(serviceProvider(widget.serviceId)).value;
    final isOwn = service?.providerId == ref.watch(effectiveSessionProvider).neighborId;
    final existing = mine.value?.where((r) => r.serviceId == widget.serviceId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(t.writeReview)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: spaced([
            if (isOwn)
              Text(t.selfReview)
            else if (existing != null) ...[
              Text(t.duplicateReview),
              ReviewCard(review: existing),
            ] else ...[
              Semantics(
                liveRegion: true,
                child: Text(t.starsLabel(_rating), style: Theme.of(context).textTheme.titleMedium),
              ),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var n = 1; n <= 5; n++)
                    Semantics(
                      label: t.starsLabel(n),
                      selected: _rating == n,
                      button: true,
                      excludeSemantics: true,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: IconButton(
                          tooltip: t.starsLabel(n),
                          onPressed: () => setState(() => _rating = n),
                          iconSize: 40,
                          icon: Icon(
                            n <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: n <= _rating
                                ? const Color(0xFFE0A200)
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              TextField(
                controller: _comment,
                maxLines: 4,
                decoration: InputDecoration(labelText: t.commentLabel, errorText: _commentError),
              ),
              Text(t.dictationHelp),
              OutlinedButton.icon(
                icon: Icon(_listening ? Icons.stop : Icons.mic_none),
                label: Text(_listening ? t.stopDictation : t.dictateComment),
                onPressed: _busy ? null : _dictate,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(t.addPhotos),
                onPressed: _busy || _photos.length >= 3
                    ? null
                    : () async {
                        try {
                          final selected = await ref
                              .read(photoPickerProvider)
                              .pick(3 - _photos.length);
                          if (mounted) {
                            setState(() => _photos.addAll(selected.take(3 - _photos.length)));
                          }
                        } catch (_) {
                          if (mounted) setState(() => _error = t.permissionPhotos);
                        }
                      },
              ),
              Text(t.photoLimit),
              for (var i = 0; i < _photos.length; i++)
                ListTile(
                  title: Text(t.photoSelected(i + 1)),
                  trailing: IconButton(
                    tooltip: t.removePhoto(i + 1),
                    onPressed: () => setState(() => _photos.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                ),
              if (_photos.any((p) => p.uploadedFileId == null)) ...[
                Text(t.photosPending),
                OutlinedButton(
                  onPressed: _busy ? null : () => _save(withoutPhotos: true),
                  child: Text(t.sendWithoutPhotos),
                ),
              ],
              if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
              FilledButton(
                onPressed: _busy || !mine.hasValue ? null : _save,
                child: Text(_busy ? t.loadingAction : t.submitReview),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
