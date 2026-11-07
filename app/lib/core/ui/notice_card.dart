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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: fg, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: TextStyle(color: fg, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
