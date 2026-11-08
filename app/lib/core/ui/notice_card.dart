import 'package:flutter/material.dart';
import 'package:vecinal/core/theme/vecinal_tokens.dart';

/// Aviso destacado con ícono, título y detalle.
///
/// Usa [Semantics] con [liveRegion] para que el lector de pantalla anuncie
/// cambios de estado sin que el vecino tenga que navegar hasta él.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.vecinalTokens;
    final bg = background ?? scheme.surfaceContainerHighest;
    final fg = foreground ?? scheme.onSurface;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: EdgeInsets.all(tokens.spaceLg),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(tokens.radiusLg)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg),
            SizedBox(width: tokens.spaceSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: tokens.spaceXs),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
