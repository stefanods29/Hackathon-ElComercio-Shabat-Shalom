// Paleta de colores de Winki según DISENO_UI_UX.md
import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/design-system/tokens/winki_tokens.dart';

export 'package:vecinal/features/prototipo/presentation/design-system/tokens/winki_tokens.dart';

ThemeData winkiTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'AtkinsonHyperlegible',
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    scaffoldBackgroundColor: kBackgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: kPrimaryColor,
      primary: kPrimaryColor,
      secondary: kSecondaryColor,
      tertiary: kAccentColor,
      surface: kSurfaceColor,
      error: kErrorColor,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: kTextColor,
      onError: Colors.white,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: kFontDisplayLG,
        fontWeight: FontWeight.bold,
        color: kTextColor,
      ),
      headlineLarge: TextStyle(
        fontSize: kFontHeadlineLG,
        fontWeight: FontWeight.bold,
        color: kTextColor,
      ),
      headlineMedium: TextStyle(
        fontSize: kFontHeadlineMD,
        fontWeight: FontWeight.w600,
        color: kTextColor,
      ),
      headlineSmall: TextStyle(
        fontSize: kFontHeadlineSM,
        fontWeight: FontWeight.w600,
        color: kTextColor,
      ),
      bodyLarge: TextStyle(fontSize: kFontBodyLG, color: kTextColor),
      bodyMedium: TextStyle(fontSize: kFontBodyMD, color: kTextSecondaryColor),
      bodySmall: TextStyle(fontSize: kFontBodySM, color: kTextSecondaryColor),
      labelLarge: TextStyle(
        fontSize: kFontBodyMD,
        fontWeight: FontWeight.w500,
        color: kTextColor,
        letterSpacing: 0.15,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLarge)),
        elevation: 0,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shadowColor: Colors.transparent,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimaryColor,
        side: const BorderSide(color: kPrimaryColor, width: 1.25),
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLarge)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMedium)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: kBackgroundColor,
      foregroundColor: kTextColor,
      centerTitle: false,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData().copyWith(
      color: kSurfaceColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: const BorderSide(color: kBorderColor),
      ),
    ),
    dividerTheme: const DividerThemeData(space: 1, thickness: 1, color: kBorderColor),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: const BorderSide(color: kPrimaryColor, width: kBorderFocusWidth),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: const BorderSide(color: kErrorColor),
      ),
    ),
  );
}

class WinkiLogo extends StatelessWidget {
  final double size;
  final bool withText;
  const WinkiLogo({super.key, this.size = 56, this.withText = true});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: kPrimaryColor,
            borderRadius: BorderRadius.circular(kRadiusPill),
          ),
          child: Stack(
            children: [
              Positioned(
                left: size * 0.22,
                top: size * 0.30,
                child: Container(
                  width: size * 0.12,
                  height: size * 0.12,
                  decoration: BoxDecoration(color: kSecondaryColor, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                left: size * 0.58,
                top: size * 0.30,
                child: Container(
                  width: size * 0.12,
                  height: size * 0.12,
                  decoration: BoxDecoration(color: kSecondaryColor, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                left: size * 0.25,
                top: size * 0.58,
                child: Container(
                  width: size * 0.40,
                  height: size * 0.12,
                  decoration: BoxDecoration(
                    color: kSecondaryColor,
                    borderRadius: BorderRadius.circular(kRadiusPill),
                  ),
                ),
              ),
              Positioned(
                left: size * 0.72,
                top: size * 0.58,
                child: Container(
                  width: size * 0.18,
                  height: size * 0.18,
                  decoration: BoxDecoration(color: kAccentColor, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
        if (withText) ...[
          const SizedBox(height: 12),
          const Text(
            'Winki',
            style: TextStyle(
              fontSize: kFontDisplayLG,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
              letterSpacing: -0.02,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size * 0.14,
                height: size * 0.14,
                decoration: BoxDecoration(color: kAccentColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Container(
                width: size * 0.14,
                height: size * 0.14,
                decoration: BoxDecoration(color: kAccentColor, shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
