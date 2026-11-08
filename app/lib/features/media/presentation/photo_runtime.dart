import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/features/media/data/providers.dart';

class PhotoRuntime extends ConsumerStatefulWidget {
  const PhotoRuntime({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PhotoRuntime> createState() => _PhotoRuntimeState();
}

class _PhotoRuntimeState extends ConsumerState<PhotoRuntime> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.resumed && ref.read(environmentProvider).enablePhotos) {
      unawaited(ref.read(photoControllerProvider.notifier).sync());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(environmentProvider).enablePhotos) {
      ref.watch(photoControllerProvider);
      ref.listen(mediaCredentialsProvider, (previous, next) {
        if (previous != null && previous.userId != next?.userId) {
          unawaited(ref.read(photoTransferProvider).cancelOwner(previous.userId));
        }
      });
    }
    return widget.child;
  }
}
