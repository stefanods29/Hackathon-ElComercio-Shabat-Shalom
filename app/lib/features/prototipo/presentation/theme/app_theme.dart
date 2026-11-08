// Paleta de colores de la app vecinal
// Principal: #0F766E (teal)
// Secundario: #1E3A5F (azul oscuro)
// Acento: #F4B942 (amarillo dorado)
// Fondo: #F8FAFC (gris muy claro)
// Texto: #1F2937 (gris oscuro)

import 'package:flutter/material.dart';

const Color kPrimaryColor = Color(0xFF0F766E);
const Color kSecondaryColor = Color(0xFF1E3A5F);
const Color kAccentColor = Color(0xFFF4B942);
const Color kBackgroundColor = Color(0xFFF8FAFC);
const Color kTextColor = Color(0xFF1F2937);
const Color kSurfaceColor = Colors.white;
const Color kErrorColor = Color(0xFFDC2626);
const Color kSuccessColor = Color(0xFF059669);
const Color kWarningColor = Color(0xFFF59E0B);

/// Colores de estado de publicación
const Color kStatusSavedColor = Color(0xFFF59E0B);    // ámbar
const Color kStatusAcceptedColor = Color(0xFF059669); // verde
const Color kStatusRejectedColor = Color(0xFFDC2626); // rojo

/// Tema de la app con jerarquía de color
ThemeData prototypeTheme() {
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
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: kTextColor,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: kTextColor,
      ),
      titleMedium: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: kTextColor,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        color: kTextColor,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: Color(0xFF6B7280),
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: kTextColor,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: kPrimaryColor,
        side: const BorderSide(color: kPrimaryColor),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    cardTheme: const CardThemeData().copyWith(
      color: kSurfaceColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kSurfaceColor,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kPrimaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kErrorColor),
      ),
    ),
  );
}
