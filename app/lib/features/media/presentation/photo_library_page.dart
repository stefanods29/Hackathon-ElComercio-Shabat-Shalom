import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/features/media/data/providers.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/presentation/local_photo_preview.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class PhotoLibraryPage extends ConsumerStatefulWidget {
  const PhotoLibraryPage({super.key});
  @override
  ConsumerState<PhotoLibraryPage> createState() => _PhotoLibraryPageState();
}

class _PhotoLibraryPageState extends ConsumerState<PhotoLibraryPage> with WidgetsBindingObserver {
  bool _picking = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ref.read(photoControllerProvider.notifier).sync());
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final enabled = ref.watch(environmentProvider).enablePhotos;
    return Scaffold(
      appBar: AppBar(title: Text(texts.photosTitle)),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: !enabled
                ? Padding(padding: const EdgeInsets.all(24), child: Text(texts.photosDisabled))
                : ref
                      .watch(photoControllerProvider)
                      .when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, _) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(texts.photosStorageFailed),
                        ),
                        data: (photos) => ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          children: [
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.photo_library_outlined,
                                      size: 36,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      texts.photosHeading,
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(texts.photosPrivacy),
                                    if (ref.watch(mediaCredentialsProvider) == null) ...[
                                      const SizedBox(height: 12),
                                      Text(texts.photosLocalOnly),
                                    ],
                                    const SizedBox(height: 20),
                                    FilledButton.icon(
                                      onPressed: _picking ? null : _add,
                                      icon: const Icon(Icons.add_photo_alternate_outlined),
                                      label: Text(
                                        _picking ? texts.photosPreparing : texts.photosChoose,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (photos.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(texts.photosEmpty, textAlign: TextAlign.center),
                              ),
                            for (final photo in photos)
                              _PhotoCard(
                                key: ValueKey('${photo.ownerId}/${photo.id}'),
                                photo: photo,
                              ),
                          ],
                        ),
                      ),
          ),
        ),
      ),
    );
  }

  Future<void> _add() async {
    setState(() {
      _picking = true;
    });
    try {
      await ref.read(photoControllerProvider.notifier).add();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).photosSelectionFailed)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _picking = false;
        });
      }
    }
  }
}

class _PhotoCard extends ConsumerStatefulWidget {
  const _PhotoCard({super.key, required this.photo});
  final LocalPhoto photo;
  @override
  ConsumerState<_PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends ConsumerState<_PhotoCard> {
  @override
  Widget build(BuildContext context) {
    final photo = widget.photo;
    final texts = AppLocalizations.of(context);
    final status = switch (photo.stage) {
      LocalPhotoStage.queued => texts.photosQueued,
      LocalPhotoStage.uploading => texts.photosUploading,
      LocalPhotoStage.processing => texts.photosProcessing,
      LocalPhotoStage.ready => texts.photosReady,
      LocalPhotoStage.failed => texts.photosFailed,
      LocalPhotoStage.removing => texts.photosRemoving,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(height: 180, child: LocalPhotoPreview(photo: photo)),
            ),
            const SizedBox(height: 12),
            Semantics(liveRegion: true, child: Text(status)),
            if (photo.stage == LocalPhotoStage.uploading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: photo.progress),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (photo.stage == LocalPhotoStage.failed)
                  TextButton.icon(
                    onPressed: () => ref.read(photoControllerProvider.notifier).retry(photo.id),
                    icon: const Icon(Icons.refresh),
                    label: Text(texts.photosRetry),
                  ),
                if (photo.stage != LocalPhotoStage.removing)
                  TextButton.icon(
                    onPressed: () => _remove(context),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(texts.photosDelete),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final texts = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(texts.photosDelete),
        content: Text(texts.photosDeleteExplanation),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(texts.photosKeep)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(texts.photosDelete),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await ref.read(photoControllerProvider.notifier).remove(widget.photo.id);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texts.photosFailed)));
        }
      }
    }
  }
}
