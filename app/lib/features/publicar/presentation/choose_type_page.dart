import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/core/ui/simple_mode.dart';
import 'package:vecinal/features/publicar/domain/suggestions.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Pantalla de elección de tipo de publicación (toque 2 del flujo).
class ChooseTypePage extends ConsumerWidget {
  const ChooseTypePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final simpleModeAsync = ref.watch(simpleModeProvider);
    final scale = simpleModeAsync.value == true ? simpleModeTextScale : 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.publishAction),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                texts.chooseTypeTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 24 * scale),
              ),
              const SizedBox(height: 32),
              ...publishSuggestions.map((suggestion) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LargeButton(
                    icon: _iconForType(suggestion.type),
                    label: suggestion.type.apiValue.toUpperCase(),
                    fullWidth: true,
                    onPressed: () => context.push('${Routes.publish}/${suggestion.type.apiValue}'),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(PostType type) {
    switch (type) {
      case PostType.offer:
        return Icons.handyman;
      case PostType.need:
        return Icons.help_outline;
      case PostType.lend:
        return Icons.build;
      case PostType.donate:
        return Icons.card_giftcard;
      case PostType.exchange:
        return Icons.swap_horiz;
      case PostType.ride:
        return Icons.directions_car;
    }
  }
}
