import 'package:flutter/material.dart';

class AppTheme {
  // ─── Core Colors ───────────────────────────────────
  static const Color bgPrimary    = Color(0xFF080808);
  static const Color bgSecondary  = Color(0xFF111111);
  static const Color bgTertiary   = Color(0xFF1A1A1A);

  // ─── Accent Colors ─────────────────────────────────
  static const Color pink         = Color(0xFFFFB3C6);  // Soft baby pink
  static const Color purple       = Color(0xFFD4B8FF);  // Soft baby purple
  static const Color pinkDeep     = Color(0xFFFF85A1);  // Deeper pink
  static const Color purpleDeep   = Color(0xFFB794FF);  // Deeper purple

  // ─── Glass Colors ──────────────────────────────────
  static const Color glassWhite   = Color(0x14FFFFFF);  // 8% white
  static const Color glassBorder  = Color(0x1FFFFFFF);  // 12% white
  static const Color glassShimmer = Color(0x0AFFFFFF);  // 4% white

  // ─── Text Colors ───────────────────────────────────
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted     = Color(0xFF555555);

  // ─── Gradients ─────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFB3C6), Color(0xFFD4B8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF080808), Color(0xFF0D0D0D), Color(0xFF111111)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFFFB3C6), Color(0xFFFF85A1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFFD4B8FF), Color(0xFFB794FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0x22FFB3C6), Color(0x22D4B8FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: pink,
      colorScheme: const ColorScheme.dark(
        primary: pink,
        secondary: purple,
        surface: bgSecondary,
        background: bgPrimary,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary,
          fontWeight: FontWeight.w800),
        displayMedium: TextStyle(color: textPrimary,
          fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: textPrimary,
          fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textMuted),
      ),
    );
  }
}