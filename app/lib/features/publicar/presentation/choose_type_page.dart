import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/vecinal_tokens.dart';
import 'package:vecinal/features/publicar/domain/suggestions.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Elegir uno de los seis tipos es el segundo paso del flujo de tres toques.
class ChooseTypePage extends StatelessWidget {
  const ChooseTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final tokens = context.vecinalTokens;

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.publishAction),
        leading: IconButton(
          key: const ValueKey<String>('back-to-wall'),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
              tokens.spaceLg,
              tokens.spaceLg,
              tokens.spaceLg,
              tokens.spaceMd,
            ),
            sliver: SliverToBoxAdapter(
              child: Text(texts.chooseTypeTitle, style: Theme.of(context).textTheme.headlineSmall),
            ),
          ),
          SliverLayoutBuilder(
            builder: (context, constraints) {
              final columns = switch (constraints.crossAxisExtent) {
                < 600 => 2,
                < 840 => 3,
                _ => 4,
              };
              final textScale = MediaQuery.textScalerOf(context).scale(18) / 18;
              return SliverPadding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  tokens.spaceLg,
                  0,
                  tokens.spaceLg,
                  tokens.space2xl,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: tokens.choiceTileHeight * textScale,
                    mainAxisSpacing: tokens.spaceMd,
                    crossAxisSpacing: tokens.spaceMd,
                  ),
                  itemCount: publishSuggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = publishSuggestions[index];
                    return _PublishTypeTile(
                      label: suggestion.type.apiValue,
                      category: suggestion.category,
                      icon: _iconForType(suggestion.type),
                      onTap: () => context.push('${Routes.publish}/${suggestion.type.apiValue}'),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _iconForType(PostType type) {
    return switch (type) {
      PostType.offer => Icons.handyman_outlined,
      PostType.need => Icons.help_outline,
      PostType.lend => Icons.build_outlined,
      PostType.donate => Icons.card_giftcard_outlined,
      PostType.exchange => Icons.swap_horiz,
      PostType.ride => Icons.directions_car_outlined,
    };
  }
}

class _PublishTypeTile extends StatelessWidget {
  const _PublishTypeTile({
    required this.label,
    required this.category,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String category;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.vecinalTokens;
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('publish-type-${label.toLowerCase()}'),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 32),
              SizedBox(height: tokens.spaceSm),
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spaceXs),
              Text(category, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
