import 'package:flutter/material.dart';

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
    final bg = background ?? scheme.surfaceContainerHighest;
    final fg = foreground ?? scheme.onSurface;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: fg.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: TextStyle(color: fg, fontSize: 14, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
