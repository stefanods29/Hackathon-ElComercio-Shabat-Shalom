import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            texts.chooseTypeTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 24 * scale),
          ),
          const SizedBox(height: 20),
          _TypeTile(
            icon: Icons.handyman_outlined,
            label: texts.offerService,
            highlighted: true,
            onTap: () => context.push(Routes.publishService),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              for (final suggestion in publishSuggestions)
                _TypeTile(
                  icon: _iconForType(suggestion.type),
                  label: suggestion.type.apiValue.toUpperCase(),
                  onTap: () => context.push('${Routes.publish}/${suggestion.type.apiValue}'),
                ),
            ],
          ),
        ],
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

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = highlighted ? scheme.onPrimary : scheme.primary;
    return Card(
      color: highlighted ? scheme.primary : null,
      shadowColor: highlighted ? scheme.primary.withValues(alpha: 0.5) : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: highlighted ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: foreground),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: TextStyle(
                  color: highlighted ? scheme.onPrimary : scheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
