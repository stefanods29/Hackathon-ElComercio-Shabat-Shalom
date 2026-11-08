import 'package:flutter/material.dart';
import 'package:vecinal/core/theme/vecinal_tokens.dart';

/// Accessible theme (WCAG 2.2 AA target, section 6 of the architecture).
///
/// High contrast, touch targets of at least 48 dp and text that respects the font size the
/// neighbor picked on the phone. Lot D extends it (simple mode, golden tests).
abstract final class AccessibleTheme {
  static const Color _seed = Color(0xFF0B5FAD);
  static const Size _minButtonSize = Size(48, 52);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData highContrastLight() => _build(Brightness.light, contrastLevel: 1);

  static ThemeData highContrastDark() => _build(Brightness.dark, contrastLevel: 1);

  static ThemeData _build(Brightness brightness, {double contrastLevel = 0.5}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      contrastLevel: contrastLevel,
    );
    const buttonText = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    const tokens = VecinalTokens.standard;
    return ThemeData(
      colorScheme: scheme,
      fontFamily: 'AtkinsonHyperlegible',
      extensions: const [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        scrolledUnderElevation: 1,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: EdgeInsets.symmetric(horizontal: tokens.spaceLg, vertical: tokens.spaceMd),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorMaxLines: 2,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusCard)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusLg)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primaryContainer,
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _minButtonSize,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusLg)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _minButtonSize,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusLg)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: _minButtonSize,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(tokens.radiusMd)),
        ),
      ),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    );
  }
}
