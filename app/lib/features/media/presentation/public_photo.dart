import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/ui/image_policy.dart';

/// Other lots supply an already authorized public derivative. Private upload URLs never belong here.
class PublicPhoto extends ConsumerWidget {
  const PublicPhoto({super.key, required this.url, required this.description, this.blurhash});
  final Uri url;
  final String description;
  final String? blurhash;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(imagesEnabledProvider)) return const SizedBox.shrink();
    final placeholder = blurhash == null
        ? const Center(child: Icon(Icons.image_outlined))
        : BlurHash(hash: blurhash!);
    if (url.scheme != 'https' || url.userInfo.isNotEmpty || url.hasQuery) return placeholder;
    return Image.network(
      url.toString(),
      semanticLabel: description,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null ? child : placeholder,
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}
