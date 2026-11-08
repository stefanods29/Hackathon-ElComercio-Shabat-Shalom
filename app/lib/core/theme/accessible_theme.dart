import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Accessible theme (WCAG 2.2 AA target, section 6 of the architecture) with the visual identity
/// of the UI prototype (`prototipo/ui-skeleton`): teal, navy and amber on a light background,
/// rounded cards and buttons.
///
/// High contrast, touch targets of at least 48 dp and text that respects the font size the
/// neighbor picked on the phone. Lot D extends it (simple mode, golden tests).
abstract final class AccessibleTheme {
  /// Teal 700: 5.5:1 against white, enough for text and icons.
  static const Color primary = Color(0xFF0F766E);
  static const Color secondary = Color(0xFF1E3A5F);
  static const Color accent = Color(0xFFF4B942);
  static const Color background = Color(0xFFF8FAFC);
  static const Color text = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color border = Color(0xFFE5E7EB);
  static const Color error = Color(0xFFB91C1C);

  static const double radiusMedium = 12;
  static const double radiusCard = 20;
  static const Size _minButtonSize = Size(48, 48);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final generated = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      contrastLevel: 0.5,
    );
    final scheme = light
        ? generated.copyWith(
            primary: primary,
            onPrimary: Colors.white,
            secondary: secondary,
            onSecondary: Colors.white,
            tertiary: accent,
            onTertiary: text,
            surface: Colors.white,
            onSurface: text,
            onSurfaceVariant: textSecondary,
            outline: textSecondary,
            outlineVariant: border,
            error: error,
            onError: Colors.white,
          )
        : generated;
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium));
    const buttonText = TextStyle(fontSize: 18, fontWeight: FontWeight.w600);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    final base = ThemeData(colorScheme: scheme, brightness: brightness);
    return base.copyWith(
      scaffoldBackgroundColor: light ? background : scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: light ? background : scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: buttonPadding,
          textStyle: buttonText,
          shape: rounded,
          elevation: 1,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: buttonPadding,
          textStyle: buttonText,
          shape: rounded,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: buttonPadding,
          textStyle: buttonText,
          shape: rounded,
          side: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: _minButtonSize,
          textStyle: buttonText,
          shape: rounded,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: light ? 1 : 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: light ? border : scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light ? Colors.white : scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: light ? border : scheme.outlineVariant),
        labelStyle: TextStyle(fontWeight: FontWeight.w600, color: scheme.onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurface),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
      ),
      dividerTheme: DividerThemeData(color: light ? border : scheme.outlineVariant),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      // Smooth screen changes: fade forward on Android, the native slide on iOS.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
