import 'package:flutter/material.dart';

/// Botón grande y accesible (mínimo 48 dp de objetivo táctil)
/// para el prototipo de UI/UX.
class ProtoButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool fullWidth;
  final bool secondary;

  const ProtoButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.fullWidth = false,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: secondary ? null : onPressed,
      icon: icon != null ? Icon(icon, size: 20) : const SizedBox.shrink(),
      label: Text(text, style: const TextStyle(fontSize: 16)),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: secondary ? const Color(0xFF0B5FAD).withValues(alpha: 0.15) : null,
        foregroundColor: secondary ? const Color(0xFF0B5FAD) : Colors.white,
      ),
    );

    if (fullWidth) return button;
    return SizedBox(width: 240, child: button);
  }
}
