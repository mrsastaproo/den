import 'package:flutter/material.dart';

class AppTheme {
  // Purple gradient palette (exact from image)
  static const Color bgPurpleDark = Color(0xFF2D1B69);
  static const Color bgPurpleMid = Color(0xFF6B35B8);
  static const Color bgPurpleLight = Color(0xFF9B59D4);
  static const Color bgWhiteCard = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFFB44FE8);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF8B8BAD);
  static const Color textMuted = Color(0xFFB0B0C8);

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFF1A0533), Color(0xFF6B35B8), Color(0xFFAB5FE8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF7B3FD4), Color(0xFFAB5FE8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPurpleDark,
      primaryColor: bgPurpleMid,
      colorScheme: const ColorScheme.dark(
        primary: bgPurpleMid,
        secondary: accent,
        surface: bgWhiteCard,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1A0533),
        selectedItemColor: Color(0xFFE040FB),
        unselectedItemColor: Color(0xFF7B6B9B),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
    );
  }
}