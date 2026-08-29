import 'package:flutter/material.dart';

// Riyo brand theme. Brand color matches the Riyo logo (#7367f0).
class RiyoTheme {
  static const Color brand = Color(0xFF7367F0);
  static const Color brandDark = Color(0xFF5B4FCF);
  static const Color brandLight = Color(0xFFEDEAFD);
  static const Color bg = Color(0xFFF6F7FB);
  static const Color text = Color(0xFF2B2B3A);
  static const Color muted = Color(0xFF8A8AA0);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        primaryColor: brand,
        scaffoldBackgroundColor: bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brand,
          primary: brand,
          secondary: brandDark,
          background: bg,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: brand,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: brand,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: brandLight,
          labelStyle: const TextStyle(color: brandDark, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: text),
          titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: text),
          bodyMedium: TextStyle(fontSize: 14, color: text),
        ),
      );
}
