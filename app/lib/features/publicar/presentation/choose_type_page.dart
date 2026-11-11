import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/publicar/domain/suggestions.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/l10n/app_localizations.dart';

const _tilePadding = 18.0;
const _tileLabelSize = 17.0;

/// Pantalla de elección de tipo de publicación (toque 2 del flujo).
class ChooseTypePage extends StatelessWidget {
  const ChooseTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    const labelSize = _tileLabelSize;

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
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 20),
          _TypeTile(
            icon: Icons.handyman_outlined,
            label: texts.offerService,
            labelSize: labelSize,
            highlighted: true,
            onTap: () => context.push(Routes.publishService),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 12.0;
              final width = constraints.maxWidth;
              final columnWidth = (width - gap) / 2;
              final scaledLabel = MediaQuery.textScalerOf(context).scale(labelSize);
              final minTileWidth = 2 * _tilePadding + scaledLabel * 7;
              final tileWidth = columnWidth >= minTileWidth ? columnWidth : width;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final suggestion in publishSuggestions)
                    SizedBox(
                      width: tileWidth,
                      child: _TypeTile(
                        icon: _iconForType(suggestion.type),
                        label: suggestion.type.apiValue.toUpperCase(),
                        labelSize: labelSize,
                        onTap: () => context.push('${Routes.publish}/${suggestion.type.apiValue}'),
                      ),
                    ),
                ],
              );
            },
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
    required this.labelSize,
    required this.onTap,
    this.highlighted = false,
  });
  final IconData icon;
  final String label;
  final double labelSize;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    final (background, textColor, iconBackground, iconColor) = switch ((dark, highlighted)) {
      (true, true) => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        AccessibleTheme.action(scheme),
        AccessibleTheme.onAction(scheme),
      ),
      (true, false) => (
        scheme.surface,
        scheme.onSurface,
        scheme.surfaceContainerHigh,
        scheme.primary,
      ),
      (false, true) => (
        scheme.primary,
        scheme.onPrimary,
        scheme.onPrimary.withValues(alpha: 0.2),
        scheme.onPrimary,
      ),
      (false, false) => (
        theme.cardTheme.color,
        scheme.onSurface,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
    };
    return Card(
      color: background,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AccessibleTheme.radiusCard),
        side: BorderSide(color: highlighted ? scheme.primary : AccessibleTheme.hairline(scheme)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_tilePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: iconBackground, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: labelSize,
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
