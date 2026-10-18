import 'package:flutter/material.dart';

class TelegramTheme {
  // Telegram Brand Colors
  static const Color primaryBlue = Color(0xFF2AABEE);
  static const Color darkBlue = Color(0xFF229ED9);
  static const Color accentGreen = Color(0xFF4FAE4E);
  static const Color accentOrange = Color(0xFFE57B18);

  // Dark Theme Palette (Telegram Android/iOS Dark)
  static const Color darkBg = Color(0xFF0E1621);
  static const Color darkSurface = Color(0xFF17212B);
  static const Color darkCard = Color(0xFF242F3D);
  static const Color darkText = Color(0xFFF5F5F5);
  static const Color darkSubtext = Color(0xFF7F8C99);
  static const Color darkDivider = Color(0xFF101921);
  static const Color darkOutMessage = Color(0xFF2B5278);
  static const Color darkInMessage = Color(0xFF182533);
  static const Color darkChatBg = Color(0xFF0E1621);

  // Light Theme Palette (Telegram Android/iOS Classic)
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF4F4F5);
  static const Color lightText = Color(0xFF000000);
  static const Color lightSubtext = Color(0xFF8E8E93);
  static const Color lightDivider = Color(0xFFE5E5EA);
  static const Color lightOutMessage = Color(0xFFEFFDDE);
  static const Color lightInMessage = Color(0xFFFFFFFF);
  static const Color lightChatBg = Color(0xFFEFE7DE);

  // Dark Theme Data
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: darkBg,
      cardColor: darkSurface,
      dividerColor: darkDivider,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: primaryBlue,
        surface: darkSurface,
        onPrimary: Colors.white,
        onSurface: darkText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }

  // Light Theme Data
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: lightBg,
      cardColor: lightBg,
      dividerColor: lightDivider,
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: primaryBlue,
        surface: lightBg,
        onPrimary: Colors.white,
        onSurface: lightText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryBlue,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
      ),
    );
  }
}
