import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

abstract final class HomiziTheme {
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: HomiziColors.accent,
      onPrimary: HomiziColors.ink,
      primaryContainer: HomiziColors.accentWash,
      onPrimaryContainer: HomiziColors.ink,
      secondary: HomiziColors.ink,
      onSecondary: HomiziColors.white,
      secondaryContainer: HomiziColors.mist,
      onSecondaryContainer: HomiziColors.ink,
      tertiary: HomiziColors.accent,
      onTertiary: HomiziColors.ink,
      tertiaryContainer: HomiziColors.accentWash,
      onTertiaryContainer: HomiziColors.ink,
      error: Color(0xFFB3261E),
      onError: HomiziColors.white,
      errorContainer: Color(0xFFF9DEDC),
      onErrorContainer: Color(0xFF410E0B),
      surface: HomiziColors.white,
      onSurface: HomiziColors.ink,
      onSurfaceVariant: HomiziColors.muted,
      outline: HomiziColors.line,
      outlineVariant: HomiziColors.line,
      shadow: Color(0x1A000000),
      scrim: Color(0x99000000),
      inverseSurface: HomiziColors.ink,
      onInverseSurface: HomiziColors.white,
      inversePrimary: HomiziColors.accent,
      surfaceTint: HomiziColors.white,
      surfaceContainerLowest: HomiziColors.white,
      surfaceContainerLow: HomiziColors.white,
      surfaceContainer: HomiziColors.white,
      surfaceContainerHigh: HomiziColors.white,
      surfaceContainerHighest: HomiziColors.mist,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: HomiziColors.white,
      canvasColor: HomiziColors.white,
    );
    final text = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: HomiziColors.ink,
      displayColor: HomiziColors.ink,
    );
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    return base.copyWith(
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.15,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          height: 1.2,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(
          color: HomiziColors.inkSoft,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          color: HomiziColors.inkSoft,
          height: 1.45,
          fontWeight: FontWeight.w500,
        ),
        bodySmall: text.bodySmall?.copyWith(
          color: HomiziColors.muted,
          height: 1.4,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      splashColor: HomiziColors.accent.withValues(alpha: 0.08),
      highlightColor: HomiziColors.accent.withValues(alpha: 0.04),
      dividerColor: HomiziColors.line,
      appBarTheme: AppBarTheme(
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: HomiziColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: HomiziColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: HomiziColors.line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HomiziColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HomiziColors.ink,
        contentTextStyle: text.bodyMedium?.copyWith(color: HomiziColors.white),
        behavior: SnackBarBehavior.floating,
        shape: rounded,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          backgroundColor: HomiziColors.accent,
          foregroundColor: HomiziColors.ink,
          disabledBackgroundColor: HomiziColors.mist,
          disabledForegroundColor: HomiziColors.muted,
          shape: rounded,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: HomiziColors.ink,
          side: const BorderSide(color: HomiziColors.line),
          shape: rounded,
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HomiziColors.ink,
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: HomiziColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HomiziColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: text.bodyMedium?.copyWith(color: HomiziColors.muted),
        hintStyle: text.bodyMedium?.copyWith(color: HomiziColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HomiziColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HomiziColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: HomiziColors.accent, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HomiziColors.white,
        selectedColor: HomiziColors.accent,
        disabledColor: HomiziColors.mist,
        labelStyle: text.labelLarge?.copyWith(fontSize: 13),
        secondaryLabelStyle: text.labelLarge?.copyWith(fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        side: const BorderSide(color: HomiziColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: HomiziColors.white,
        elevation: 0,
        height: 68,
        indicatorColor: HomiziColors.accentWash,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return text.labelMedium?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? HomiziColors.ink : HomiziColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? HomiziColors.accent : HomiziColors.muted,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: HomiziColors.line,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
