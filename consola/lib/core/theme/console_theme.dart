import 'package:flutter/material.dart';

/// Accessible theme of the console (WCAG 2.2 AA), the same seed and contrast as the app's.
///
/// Keyboard focus is always visible: buttons get a 3 px outline in the strongest color of the
/// theme, and lists and cards a tinted background or border (see `FocusableCard`).
abstract final class ConsoleTheme {
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
    const buttonText = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    final focusSide = WidgetStateProperty.resolveWith<BorderSide?>(
      (states) => states.contains(WidgetState.focused)
          ? BorderSide(color: scheme.onSurface, width: 3)
          : null,
    );
    return ThemeData(
      colorScheme: scheme,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      focusColor: scheme.primary.withValues(alpha: 0.24),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _minButtonSize,
          textStyle: buttonText,
        ).copyWith(side: focusSide),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _minButtonSize,
          textStyle: buttonText,
        ).copyWith(side: focusSide),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: _minButtonSize,
          textStyle: buttonText,
        ).copyWith(side: focusSide),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: _minButtonSize).copyWith(side: focusSide),
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 12,
        selectedTileColor: scheme.secondaryContainer,
        selectedColor: scheme.onSecondaryContainer,
      ),
    );
  }
}

/// Text field decoration with a visible outline in every state.
InputDecoration fieldDecoration(
  String label, {
  String? helper,
  String? error,
  String? hint,
  Widget? suffix,
}) => InputDecoration(
  labelText: label,
  helperText: helper,
  helperMaxLines: 3,
  errorText: error,
  errorMaxLines: 3,
  hintText: hint,
  suffixIcon: suffix,
  border: const OutlineInputBorder(),
);
