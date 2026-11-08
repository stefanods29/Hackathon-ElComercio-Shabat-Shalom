import 'package:flutter/material.dart';

/// Botón grande accesible: objetivo táctil de al menos 48 × 48 dp, ícono + texto.
///
/// El color nunca es la única señal: siempre lleva ícono y etiqueta de texto.
class LargeButton extends StatelessWidget {
  const LargeButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.fullWidth = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 60),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: enabled ? 4 : 0,
        shadowColor: scheme.primary.withValues(alpha: 0.45),
        backgroundColor: enabled ? scheme.primary : scheme.surfaceContainerHighest,
        foregroundColor: enabled ? scheme.onPrimary : scheme.onSurfaceVariant,
      ),
      child: SizedBox(
        width: fullWidth ? double.infinity : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
