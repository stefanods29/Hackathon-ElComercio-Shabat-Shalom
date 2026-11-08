import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/media/data/providers.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/features/media/presentation/local_photo_preview.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// D selects ready local references; B validates ownership and moderation when saving the parent.
class PhotoAttachmentPicker extends ConsumerWidget {
  const PhotoAttachmentPicker({
    super.key,
    required this.selectedIds,
    required this.onChanged,
    this.maximum = 3,
  }) : assert(maximum > 0);
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;
  final int maximum;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    return ref
        .watch(photoControllerProvider)
        .when(
          data: (photos) => Column(
            children: [
              for (final photo in photos.where((photo) => photo.stage == LocalPhotoStage.ready))
                CheckboxListTile(
                  secondary: SizedBox(
                    width: 48,
                    height: 48,
                    child: LocalPhotoPreview(photo: photo, fit: BoxFit.cover),
                  ),
                  title: Text(texts.photosAttach),
                  subtitle: Text(texts.photosReady),
                  value: selectedIds.contains(photo.id),
                  onChanged: !selectedIds.contains(photo.id) && selectedIds.length >= maximum
                      ? null
                      : (selected) {
                          final ids = {...selectedIds};
                          if (selected == true) {
                            if (ids.length >= maximum) return;
                            ids.add(photo.id);
                          } else {
                            ids.remove(photo.id);
                          }
                          onChanged(List.unmodifiable(ids));
                        },
                ),
              if (photos.every((photo) => photo.stage != LocalPhotoStage.ready))
                Text(texts.photosPrepareFirst),
            ],
          ),
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(texts.photosStorageFailed),
        );
  }
}
