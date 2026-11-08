// Paleta de colores de Winki según DISENO_UI_UX.md
import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF0F766E);
const Color kSecondaryColor = Color(0xFF1E3A5F);
const Color kAccentColor = Color(0xFFF4B942);
const Color kBackgroundColor = Color(0xFFF8FAFC);
const Color kTextColor = Color(0xFF1F2937);
const Color kTextSecondaryColor = Color(0xFF4B5563);
const Color kSurfaceColor = Colors.white;
// Dark tones retain readable contrast on white and lightly tinted surfaces.
const Color kErrorColor = Color(0xFFB91C1C);
const Color kSuccessColor = Color(0xFF065F46);
const Color kWarningColor = Color(0xFF92400E);
const Color kStatusSavedColor = kWarningColor;
const Color kStatusAcceptedColor = kSuccessColor;
const Color kStatusRejectedColor = kErrorColor;

const double kSpacingBase = 4.0;
const double kSpacingStack = 12.0;
const double kSpacingGutter = 16.0;
const double kSpacingContainer = 20.0;
const double kRadiusSmall = 4.0;
const double kRadiusMedium = 8.0;
const double kRadiusLarge = 12.0;
const double kRadiusExtraLarge = 16.0;
const double kRadiusCard = 20.0;
const double kRadiusCardLarge = 26.0;
const double kRadiusPill = 9999.0;
const double kFontDisplayLG = 32.0;
const double kFontHeadlineLG = 22.0;
const double kFontHeadlineMD = 18.0;
const double kFontHeadlineSM = 16.0;
const double kFontBodyLG = 16.0;
const double kFontBodyMD = 14.0;
const double kFontBodySM = 12.0;
const double kFontBodyXS = 10.0;

ThemeData winkiTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
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
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLarge)),
        elevation: 4,
        shadowColor: kPrimaryColor.withValues(alpha: 0.35),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimaryColor,
        side: const BorderSide(color: kPrimaryColor),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLarge)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusMedium)),
      ),
    ),
    cardTheme: const CardThemeData().copyWith(
      color: kSurfaceColor,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusMedium),
        borderSide: const BorderSide(color: kPrimaryColor, width: 2),
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
                  decoration: BoxDecoration(color: const Color(0xFF0E5A58), shape: BoxShape.circle),
                ),
              ),
              Positioned(
                left: size * 0.58,
                top: size * 0.30,
                child: Container(
                  width: size * 0.12,
                  height: size * 0.12,
                  decoration: BoxDecoration(color: const Color(0xFF0E5A58), shape: BoxShape.circle),
                ),
              ),
              Positioned(
                left: size * 0.25,
                top: size * 0.58,
                child: Container(
                  width: size * 0.40,
                  height: size * 0.12,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E5A58),
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
          const SizedBox(height: 2),
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
