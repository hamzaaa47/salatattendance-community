import 'package:flutter/material.dart';
import 'package:salatattendance/app_config.dart';

/// Feste Textstufen der App. Seiten verwenden nur diese Stile
/// (über Theme.of(context).textTheme), nie eigene fontSize-Werte.
///
///  displayLarge   36  Hauptmeldung ("Derzeit kein Gebet")
///  displayMedium  28  Header-Titel
///  displaySmall   20  Kastentitel
///  labelLarge     30  Aktuelles Gebet (Name)
///  labelMedium    18  Aktuelles Gebet (Beschriftung)
///  titleLarge     24  Abschnitt / Datum
///  titleMedium    20  Aufforderungen, Eingabezahlen
///  titleSmall     18  Gebetsnamen, Chips
///  bodyLarge      22  Kachel-Titel
///  bodyMedium     16  Fließtext, Listen
///  headlineSmall  16  Header-Untertitel, Tabellen
class AppTheme {
  static const String fontMain = "Roboto";

  static TextStyle _style(double size, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: fontMain,
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF232d3f),

    colorScheme: const ColorScheme.dark(
      primary: AppConfig.primaryColor,
      secondary: AppConfig.secondaryColor,
      surface: AppConfig.surfaceColor,
    ),

    textTheme: TextTheme(
      displayLarge: _style(36, FontWeight.w700, AppConfig.primaryColor),
      displayMedium: _style(28, FontWeight.w700, AppConfig.primaryColor),
      displaySmall: _style(20, FontWeight.w700, AppConfig.primaryColor),
      labelLarge: _style(30, FontWeight.w800, AppConfig.fullBlackColor),
      labelMedium: _style(18, FontWeight.w600, AppConfig.fullBlackColor),
      headlineSmall: _style(16, FontWeight.w700, AppConfig.fullWhiteColor),
      titleLarge: _style(24, FontWeight.w600, AppConfig.fullWhiteColor),
      titleMedium: _style(20, FontWeight.w600, AppConfig.fullWhiteColor),
      titleSmall: _style(18, FontWeight.w700, AppConfig.fullWhiteColor),
      bodyLarge: _style(22, FontWeight.w700, AppConfig.primaryColor),
      bodyMedium: _style(16, FontWeight.w500, AppConfig.fullWhiteColor),
    ),

    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      hintStyle: const TextStyle(fontSize: 16, color: Colors.white38),
      labelStyle: const TextStyle(fontSize: 16),
      errorStyle: const TextStyle(fontSize: 13),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppConfig.backgroundColor,
      titleTextStyle: _style(22, FontWeight.w700, AppConfig.fullWhiteColor),
      contentTextStyle: _style(16, FontWeight.w400, AppConfig.fullWhiteColor),
    ),
  );
}
