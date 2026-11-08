import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/media/data/providers.dart';
import 'package:vecinal/features/media/domain/local_photo.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Reads the private, encrypted local copy; no signed URL is retained by the UI.
class LocalPhotoPreview extends ConsumerStatefulWidget {
  const LocalPhotoPreview({super.key, required this.photo, this.fit = BoxFit.contain});
  final LocalPhoto photo;
  final BoxFit fit;

  @override
  ConsumerState<LocalPhotoPreview> createState() => _LocalPhotoPreviewState();
}

class _LocalPhotoPreviewState extends ConsumerState<LocalPhotoPreview> {
  late Future<Uint8List> _preview;

  Future<Uint8List> _read() async => (await ref.read(
    photoLibraryProvider.future,
  )).readBytes(widget.photo.ownerId, widget.photo.id);

  @override
  void initState() {
    super.initState();
    _preview = _read();
  }

  @override
  void didUpdateWidget(covariant LocalPhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photo.id != widget.photo.id || oldWidget.photo.ownerId != widget.photo.ownerId) {
      _preview = _read();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _preview,
    builder: (context, snapshot) => snapshot.hasData
        ? Image.memory(
            snapshot.data!,
            fit: widget.fit,
            semanticLabel: AppLocalizations.of(context).photosPreview,
            errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
          )
        : const Center(child: Icon(Icons.image_outlined)),
  );
}
