import 'package:flutter/material.dart';

/// HOMIZI design tokens. Hex values live only in this file.
///
/// Yellow and golden orange never take white text: those pairs are about
/// 1.5:1 and 1.9:1. Ink on them clears 4.5:1. White is used on success,
/// warning, and error, where those pairs also clear 4.5:1.
abstract final class HomiziColors {
  static const Color brandYellow = Color(0xFFFFD20A);
  static const Color brandGolden = Color(0xFFF9AD0B);
  static const Color brandOrange = Color(0xFFF47B0B);
  static const Color brandDeepOrange = Color(0xFFED5419);
  static const Color brandVermilion = Color(0xFFE43C1B);
  static const Color brandRedOrange = Color(0xFFCC3015);
  static const Color brandDeepRed = Color(0xFFA92310);
  static const Color brandDarkRed = Color(0xFF88180B);

  /// Primary CTA. Ink on this orange is about 6.0:1. White is about 2.7:1.
  static const Color accent = brandOrange;

  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = white;
  static const Color soft = Color(0xFFF7F8FA);

  /// Main text. About 16:1 on white.
  static const Color ink = Color(0xFF172033);

  /// Body copy. About 9.4:1 on white.
  static const Color inkSoft = Color(0xFF3A4660);

  /// Secondary text. About 5.7:1 on white and 5.4:1 on [soft].
  static const Color muted = Color(0xFF5C677A);

  static const Color line = Color(0xFFE5E7EB);
  static const Color mist = soft;

  /// Pale yellow for selected chips. Ink on this stays well above 4.5:1.
  static const Color accentWash = Color(0xFFFFF6D0);

  static const Color success = Color(0xFF16803C);
  static const Color onSuccess = white;
  static const Color successWash = Color(0xFFE7F6EC);

  static const Color warning = Color(0xFF9A6700);
  static const Color onWarning = white;
  static const Color warningWash = Color(0xFFFFF6D6);

  static const Color error = Color(0xFFB42318);
  static const Color onError = white;
  static const Color errorWash = Color(0xFFFDECEC);

  static const Color unread = error;

  static const Color shadow = Color(0x1A172033);
  static const Color shadowSoft = Color(0x14172033);
  static const Color shadowStrong = Color(0x33172033);
  static const Color shadowNight = Color(0x66000000);

  static const Color accentDisabled = Color(0x7AF47B0B);
  static const Color accentHover = Color(0x14F47B0B);
  static const Color inkPressed = Color(0x24172033);
  static const Color inkHover = Color(0x14172033);
  static const Color accentWashHover = Color(0x66FFF6D0);

  static const Color whiteVeil = Color(0xF7FFFFFF);
  static const Color whiteClear = Color(0x00FFFFFF);
  static const Color clear = Color(0x00000000);

  static const Color night = Color(0xFF121212);
  static const Color nightRaised = Color(0xFF1E1E1E);
  static const Color nightHigh = Color(0xFF2A2A2A);
  static const Color nightHighest = Color(0xFF333333);
  static const Color nightInk = Color(0xFFF5F5F5);
  static const Color nightMuted = Color(0xFFC8C8C8);
  static const Color nightLine = Color(0xFF3A3A3A);
  static const Color nightAccentContainer = brandDarkRed;
}

/// Spacing and radii shared by buttons, cards, and the search flow.
abstract final class HomiziSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double radius = 14;
  static const double cardRadius = 20;
}
