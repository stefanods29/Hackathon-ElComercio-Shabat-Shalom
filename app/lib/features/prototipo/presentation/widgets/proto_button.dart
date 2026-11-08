import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';

/// Botón grande y accesible (mínimo 48 dp de objetivo táctil)
/// usando la paleta de colores de la app.
class ProtoButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool fullWidth;
  final bool secondary;
  final bool outlined;

  const ProtoButton({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.fullWidth = false,
    this.secondary = false,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      final button = OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 20, color: kPrimaryColor) : const SizedBox.shrink(),
        label: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimaryColor,
          side: const BorderSide(color: kPrimaryColor),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return fullWidth ? button : SizedBox(width: 240, child: button);
    }

    if (secondary) {
      final button = TextButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 20, color: kPrimaryColor) : const SizedBox.shrink(),
        label: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kPrimaryColor)),
        style: TextButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: kPrimaryColor.withValues(alpha: 0.08),
        ),
      );
      return fullWidth ? button : SizedBox(width: 240, child: button);
    }

    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon, size: 20, color: Colors.white) : const SizedBox.shrink(),
      label: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
    );
    return fullWidth ? button : SizedBox(width: 240, child: button);
  }
}
