import 'package:flutter/material.dart';

/// Relación de contraste WCAG entre dos colores: (L1 + 0.05) / (L2 + 0.05),
/// donde L1 es la luminancia del color más claro y L2 la del más oscuro.
double contrastRatio(Color lighter, Color darker) {
  final l1 = lighter.computeLuminance();
  final l2 = darker.computeLuminance();
  final bright = l1 > l2 ? l1 : l2;
  final dark = l1 > l2 ? l2 : l1;
  return (bright + 0.05) / (dark + 0.05);
}
