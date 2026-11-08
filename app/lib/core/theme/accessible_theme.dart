import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Accessible theme (WCAG 2.2 AA target, section 6 of the architecture) with the team palette
/// (teal, navy and amber) in a soft style: light slate background, white surfaces lifted by
/// blurred tinted shadows instead of hard borders, generous rounded corners and spacing.
///
/// High contrast for text, touch targets of at least 48 dp and text that respects the font size
/// the neighbor picked on the phone. Lot D extends it (simple mode, golden tests).
abstract final class AccessibleTheme {
  /// Teal 700: 5.5:1 against white, enough for text and icons.
  static const Color primary = Color(0xFF0F766E);
  static const Color secondary = Color(0xFF1E3A5F);
  static const Color accent = Color(0xFFF4B942);
  static const Color background = Color(0xFFF4F7FA);
  static const Color text = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF475569);
  static const Color border = Color(0xFFE2E8F0);
  static const Color error = Color(0xFFB91C1C);

  /// Soft surface used by inputs, chips and tracks (slate 100).
  static const Color softSurface = Color(0xFFEDF2F7);

  static const double radiusMedium = 16;
  static const double radiusCard = 24;
  static const Size _minButtonSize = Size(48, 52);

  /// Blurred shadow tinted with the slate of the text, never pure black.
  static List<BoxShadow> softShadow([Color tint = const Color(0xFF64748B)]) => [
    BoxShadow(color: tint.withValues(alpha: 0.14), blurRadius: 24, offset: const Offset(0, 8)),
    BoxShadow(color: tint.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1)),
  ];

  static Color ratingColor(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark ? scheme.tertiary : const Color(0xFF956218);

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
            outline: const Color(0xFF64748B),
            outlineVariant: border,
            error: error,
            onError: Colors.white,
            // Soft containers: teal, navy and amber tints instead of the generated slate tones.
            primaryContainer: const Color(0xFFD5F2EE),
            onPrimaryContainer: const Color(0xFF064E47),
            secondaryContainer: const Color(0xFFE3EAF3),
            onSecondaryContainer: secondary,
            tertiaryContainer: const Color(0xFFFFF1CC),
            onTertiaryContainer: const Color(0xFF5B3B00),
            errorContainer: const Color(0xFFFDE8E8),
            onErrorContainer: const Color(0xFF7F1D1D),
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: const Color(0xFFF8FAFC),
            surfaceContainer: softSurface,
            surfaceContainerHigh: const Color(0xFFE6ECF2),
            surfaceContainerHighest: const Color(0xFFE2E8F0),
            shadow: const Color(0xFF64748B),
          )
        : const ColorScheme.dark(
            primary: Color(0xFF5EEAD4),
            onPrimary: Color(0xFF042F2E),
            primaryContainer: Color(0xFF134E4A),
            onPrimaryContainer: Color(0xFF99F6E4),
            secondary: Color(0xFF93C5FD),
            onSecondary: Color(0xFF172554),
            secondaryContainer: Color(0xFF1E3A5F),
            onSecondaryContainer: Color(0xFFBFDBFE),
            tertiary: Color(0xFFF4B942),
            onTertiary: Color(0xFF422A04),
            tertiaryContainer: Color(0xFF49320F),
            onTertiaryContainer: Color(0xFFFFDB87),
            error: Color(0xFFFCA5A5),
            onError: Color(0xFF450A0A),
            errorContainer: Color(0xFF641F26),
            onErrorContainer: Color(0xFFFECACA),
            surface: Color(0xFF0F172A),
            onSurface: Color(0xFFE2E8F0),
            onSurfaceVariant: Color(0xFF94A3B8),
            surfaceContainerLowest: Color(0xFF0F172A),
            surfaceContainerLow: Color(0xFF1E293B),
            surfaceContainer: Color(0xFF1E293B),
            surfaceContainerHigh: Color(0xFF273449),
            surfaceContainerHighest: Color(0xFF273449),
            outline: Color(0xFF7E90A8),
            outlineVariant: Color(0xFF71839B),
            inverseSurface: Color(0xFFE2E8F0),
            onInverseSurface: Color(0xFF1E293B),
            inversePrimary: primary,
            surfaceTint: Color(0xFF5EEAD4),
          );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 14);
    final base = ThemeData(colorScheme: scheme, brightness: brightness);
    // Derived from the platform typography so buttons and titles keep the system font.
    final buttonText = base.textTheme.labelLarge!.copyWith(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    );
    final shadowTint = light ? const Color(0xFF64748B) : Colors.black;
    return base.copyWith(
      scaffoldBackgroundColor: light ? background : scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      textTheme: base.textTheme.copyWith(
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: -0.2,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.55),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.55),
      ),
      // White bar with a hairline: it stands apart from the slate background.
      appBarTheme: AppBarTheme(
        backgroundColor: light ? Colors.white : scheme.surfaceContainer,
        shape: Border(bottom: BorderSide(color: light ? border : scheme.outlineVariant)),
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: 20,
        toolbarHeight: 64,
        titleTextStyle: base.textTheme.titleLarge!.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: buttonPadding,
          textStyle: buttonText,
          shape: rounded,
          elevation: 3,
          shadowColor: scheme.primary.withValues(alpha: 0.45),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: buttonPadding,
          textStyle: buttonText,
          shape: rounded,
          backgroundColor: light ? Colors.white : scheme.surfaceContainerHigh,
          foregroundColor: scheme.primary,
          elevation: 2,
          shadowColor: shadowTint.withValues(alpha: 0.3),
        ),
      ),
      // Soft secondary button: white pillow with a tinted shadow and a hairline edge.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: _minButtonSize,
          padding: buttonPadding,
          textStyle: buttonText,
          shape: rounded,
          backgroundColor: light ? Colors.white : scheme.surfaceContainerHigh,
          foregroundColor: scheme.primary,
          elevation: 2,
          shadowColor: shadowTint.withValues(alpha: 0.25),
          side: BorderSide(color: light ? border : scheme.outlineVariant),
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
        color: light ? scheme.surface : scheme.surfaceContainerLow,
        elevation: 3,
        shadowColor: shadowTint.withValues(alpha: 0.35),
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light ? Colors.white : scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: light ? border : scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: light ? border : scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        labelStyle: base.textTheme.labelLarge!.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        selectedColor: scheme.primaryContainer,
        backgroundColor: light ? Colors.white : scheme.surfaceContainerHigh,
        elevation: 1,
        pressElevation: 0,
        shadowColor: shadowTint.withValues(alpha: 0.3),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: light ? Colors.white : scheme.surfaceContainer,
        indicatorColor: scheme.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected) ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelMedium!.copyWith(
            fontSize: 12.5,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurface,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 6,
        highlightElevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusCard)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: light ? secondary : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
      ),
      dividerTheme: DividerThemeData(
        color: light ? border : scheme.outlineVariant,
        space: 32,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: 14,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        horizontalTitleGap: 16,
        iconColor: scheme.primary,
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.transparent : scheme.outline,
        ),
      ),
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
