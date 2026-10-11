import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

abstract final class HomiziTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: HomiziColors.seed,
      primary: HomiziColors.seed,
      onPrimary: Colors.white,
      secondary: HomiziColors.clay,
      onSecondary: Colors.white,
      surface: HomiziColors.sand,
      onSurface: HomiziColors.ink,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: HomiziColors.ink,
        displayColor: HomiziColors.ink,
      ),
      scaffoldBackgroundColor: HomiziColors.sand,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: HomiziColors.sand,
        foregroundColor: HomiziColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: const CardThemeData(
        color: HomiziColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: HomiziColors.card,
        border: OutlineInputBorder(),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: HomiziColors.card,
        indicatorColor: Color(0xFFD7EBE8),
      ),
    );
  }
}
