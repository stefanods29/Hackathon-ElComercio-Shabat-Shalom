import 'package:flutter/material.dart';

/// Accessible theme (WCAG 2.2 AA target, section 6 of the architecture).
///
/// High contrast, touch targets of at least 48 dp and text that respects the font size the
/// neighbor picked on the phone. Lot D extends it (simple mode, golden tests).
abstract final class AccessibleTheme {
  static const Color _seed = Color(0xFF0B5FAD);
  static const Size _minButtonSize = Size(48, 48);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      contrastLevel: 0.5,
    );
    const buttonText = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    return ThemeData(
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: _minButtonSize, textStyle: buttonText),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: _minButtonSize, textStyle: buttonText),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: _minButtonSize, textStyle: buttonText),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    );
  }
}
