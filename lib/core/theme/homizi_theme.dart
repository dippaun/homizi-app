import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Material 3 theme. Component size, shape, elevation, and state layers come
/// from the Material defaults (`useMaterial3: true`). The seed is the logo
/// orange. Surfaces stay white. Labels on that orange stay near-black.
abstract final class HomiziTheme {
  static const fontFamily = 'PlusJakartaSans';

  /// Plus Jakarta Sans for headings, Inter for body and labels.
  ///
  /// Headings stay near-black and heavy. Body copy is a step softer. Captions
  /// use the muted grey that still clears 4.5:1 on white.
  static TextTheme _type(TextTheme base) {
    final headings = GoogleFonts.plusJakartaSansTextTheme(base);
    final reading = GoogleFonts.interTextTheme(headings);
    TextStyle? display(TextStyle? style) {
      return style?.copyWith(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w800,
      );
    }

    TextStyle? title(TextStyle? style) {
      return style?.copyWith(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w700,
      );
    }

    TextStyle? body(TextStyle? style, Color color) {
      return style?.copyWith(color: color);
    }

    return reading.copyWith(
      displayLarge: display(headings.displayLarge),
      displayMedium: display(headings.displayMedium),
      displaySmall: display(headings.displaySmall),
      headlineLarge: display(headings.headlineLarge),
      headlineMedium: display(headings.headlineMedium),
      headlineSmall: display(headings.headlineSmall),
      titleLarge: title(headings.titleLarge),
      titleMedium: title(headings.titleMedium),
      titleSmall: title(headings.titleSmall),
      bodyLarge: body(reading.bodyLarge, HomiziColors.ink),
      bodyMedium: body(reading.bodyMedium, HomiziColors.inkSoft),
      bodySmall: body(reading.bodySmall, HomiziColors.muted),
      labelLarge: body(reading.labelLarge, HomiziColors.ink),
      labelMedium: body(reading.labelMedium, HomiziColors.ink),
      labelSmall: body(reading.labelSmall, HomiziColors.muted),
    );
  }

  static const _radius = BorderRadius.all(Radius.circular(14));

  static final ButtonStyle _filled =
      FilledButton.styleFrom(
        backgroundColor: HomiziColors.accent,
        foregroundColor: HomiziColors.ink,
        disabledBackgroundColor: const Color(0x7AF75620),
        disabledForegroundColor: HomiziColors.ink,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: HomiziColors.ink,
        ),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return const Color(0x24141414);
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0x14141414);
          }
          return null;
        }),
      );

  static final ButtonStyle _outlined =
      OutlinedButton.styleFrom(
        foregroundColor: HomiziColors.ink,
        backgroundColor: HomiziColors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        side: const BorderSide(color: HomiziColors.accent, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: _radius),
        textStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: HomiziColors.ink,
        ),
      ).copyWith(
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return HomiziColors.accentWash;
          }
          if (states.contains(WidgetState.hovered)) {
            return const Color(0x66FFE8E0);
          }
          return null;
        }),
      );

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
      scaffoldBackgroundColor: HomiziColors.white,
      canvasColor: HomiziColors.white,
    );
    final text = _type(base.textTheme);
    return base.copyWith(
      textTheme: text,
      primaryTextTheme: _type(base.primaryTextTheme),
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
      splashFactory: InkRipple.splashFactory,
      hoverColor: const Color(0x14F75620),
      cardTheme: const CardThemeData(
        color: HomiziColors.white,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x33141414),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _filled),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _outlined),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _filled),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HomiziColors.ink,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: HomiziColors.ink,
          hoverColor: HomiziColors.accentWash,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: HomiziColors.mist,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(
          fontFamily: 'Inter',
          color: HomiziColors.muted,
          fontSize: 14,
        ),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          color: HomiziColors.ink,
          fontWeight: FontWeight.w600,
        ),
        floatingLabelStyle: TextStyle(
          fontFamily: 'Inter',
          color: HomiziColors.ink,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide(color: HomiziColors.accent, width: 2),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: HomiziColors.mist,
        selectedColor: HomiziColors.accentWash,
        disabledColor: HomiziColors.mist,
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          color: HomiziColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: 'Inter',
          color: HomiziColors.ink,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: HomiziColors.ink,
        textColor: HomiziColors.ink,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
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
      splashFactory: InkRipple.splashFactory,
      cardTheme: const CardThemeData(
        color: HomiziColors.nightRaised,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x66000000),
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _filled),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _outlined),
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
    TargetPlatform.android: HomiziPageTransitionsBuilder(),
    TargetPlatform.fuchsia: HomiziPageTransitionsBuilder(),
    TargetPlatform.iOS: HomiziPageTransitionsBuilder(),
    TargetPlatform.linux: HomiziPageTransitionsBuilder(),
    TargetPlatform.macOS: HomiziPageTransitionsBuilder(),
    TargetPlatform.windows: HomiziPageTransitionsBuilder(),
  },
);

/// Smooth shared-axis move. Reduced motion shows the page immediately.
///
/// The zoom builder is the fallback when motion is allowed so route timing
/// stays the same as the rest of the app's tests.
class HomiziPageTransitionsBuilder extends PageTransitionsBuilder {
  const HomiziPageTransitionsBuilder();

  static const _zoom = ZoomPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    return _zoom.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
