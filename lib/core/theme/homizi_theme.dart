import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Material 3 theme. Component size, shape, elevation, and state layers come
/// from the Material defaults (`useMaterial3: true`). The seed is the logo
/// orange. Surfaces stay white. Labels on that orange stay near-black.
abstract final class HomiziTheme {
  static const fontFamily = 'PlusJakartaSans';

  static ThemeData light() {
    final seeded = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF75620),
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final scheme = seeded.copyWith(
      primary: HomiziColors.accent,
      onPrimary: HomiziColors.ink,
      primaryContainer: HomiziColors.accentWash,
      onPrimaryContainer: HomiziColors.ink,
      secondaryContainer: HomiziColors.accentWash,
      onSecondaryContainer: HomiziColors.ink,
      outline: HomiziColors.line,
      outlineVariant: HomiziColors.line,
      surface: HomiziColors.white,
      onSurface: HomiziColors.ink,
      onSurfaceVariant: HomiziColors.muted,
      surfaceTint: HomiziColors.white,
      surfaceContainerLowest: HomiziColors.white,
      surfaceContainerLow: HomiziColors.white,
      surfaceContainer: HomiziColors.white,
      surfaceContainerHigh: HomiziColors.white,
      surfaceContainerHighest: HomiziColors.mist,
      inverseSurface: HomiziColors.ink,
      onInverseSurface: HomiziColors.white,
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
    return base.copyWith(
      textTheme: text,
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: fontFamily,
        bodyColor: HomiziColors.ink,
        displayColor: HomiziColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        surfaceTintColor: HomiziColors.white,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: text.titleLarge?.copyWith(color: HomiziColors.ink),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        indicatorColor: HomiziColors.accentWash,
        height: 80,
        elevation: 3,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: HomiziColors.white),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HomiziColors.accent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HomiziColors.accent,
        foregroundColor: HomiziColors.ink,
      ),
      cardTheme: const CardThemeData(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: HomiziColors.line,
        space: 16,
        thickness: 1,
      ),
      pageTransitionsTheme: _transitions,
    );
  }

  /// Contrast-safe dark scheme. The app still boots in [light].
  static ThemeData dark() {
    final seeded = ColorScheme.fromSeed(
      seedColor: const Color(0xFFF75620),
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    final scheme = seeded.copyWith(
      primary: HomiziColors.accent,
      onPrimary: HomiziColors.ink,
      primaryContainer: HomiziColors.nightAccentContainer,
      onPrimaryContainer: HomiziColors.accentWash,
      secondaryContainer: HomiziColors.nightAccentContainer,
      onSecondaryContainer: HomiziColors.accentWash,
      surface: HomiziColors.night,
      onSurface: HomiziColors.nightInk,
      onSurfaceVariant: HomiziColors.nightMuted,
      outline: HomiziColors.nightLine,
      outlineVariant: HomiziColors.nightLine,
      surfaceTint: HomiziColors.night,
      surfaceContainerLowest: HomiziColors.night,
      surfaceContainerLow: HomiziColors.nightRaised,
      surfaceContainer: HomiziColors.nightRaised,
      surfaceContainerHigh: const Color(0xFF2A2A2A),
      surfaceContainerHighest: const Color(0xFF333333),
      inverseSurface: HomiziColors.white,
      onInverseSurface: HomiziColors.ink,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: HomiziColors.night,
      canvasColor: HomiziColors.night,
    );
    final text = base.textTheme.apply(
      fontFamily: fontFamily,
      bodyColor: HomiziColors.nightInk,
      displayColor: HomiziColors.nightInk,
    );
    return base.copyWith(
      textTheme: text,
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: fontFamily,
        bodyColor: HomiziColors.ink,
        displayColor: HomiziColors.ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: HomiziColors.night,
        foregroundColor: HomiziColors.nightInk,
        surfaceTintColor: HomiziColors.night,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: text.titleLarge?.copyWith(color: HomiziColors.nightInk),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: HomiziColors.night,
        surfaceTintColor: HomiziColors.night,
        indicatorColor: HomiziColors.nightAccentContainer,
        height: 80,
        elevation: 3,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: HomiziColors.nightRaised,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HomiziColors.accent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: HomiziColors.accent,
        foregroundColor: HomiziColors.ink,
      ),
      cardTheme: const CardThemeData(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: HomiziColors.nightLine,
        space: 16,
        thickness: 1,
      ),
      pageTransitionsTheme: _transitions,
    );
  }
}

const _transitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
    TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
    TargetPlatform.windows: ZoomPageTransitionsBuilder(),
  },
);
