import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryTurquoise = Color(0xFF2F8F7F);
  static const Color turquoiseDark = Color(0xFF2F8F7F);
  static const Color turquoiseDeep = Color(0xFF1F6F66);
  static const Color mintBackground = Color(0xFFF6FCFA);
  static const Color mintAppBar = Color(0xFFF4FBF9);
  static const Color mintSoft = Color(0xFFD9F3EE);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryTurquoise,
        primary: turquoiseDeep,
        surface: Colors.white,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: mintBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: mintAppBar,
        surfaceTintColor: mintAppBar,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: mintSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryTurquoise, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryTurquoise,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: turquoiseDark,
          side: BorderSide(color: turquoiseDark.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: turquoiseDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFDCEEEA), thickness: 1),
      iconTheme: const IconThemeData(color: turquoiseDark),
    );
  }
}

