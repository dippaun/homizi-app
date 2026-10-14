import 'package:flutter/material.dart';

/// Approved HOMIZI brand colours (decision PD-01).
///
/// The field is white. The only accent is the logo orange. Text is near-black
/// or a neutral grey that stays above 4.5:1 on white. Orange is not used for
/// small text: white on this orange is about 3.3:1, so labels on orange are
/// near-black (about 5.5:1).
abstract final class HomiziColors {
  static const Color accent = Color(0xFFF75620);
  static const Color white = Color(0xFFFFFFFF);

  /// Near-black. Also the label colour on [accent].
  static const Color ink = Color(0xFF141414);

  /// Body copy on white.
  static const Color inkSoft = Color(0xFF3A3A3A);

  /// Secondary text on white. About 6.7:1.
  static const Color muted = Color(0xFF5C5C5C);

  static const Color line = Color(0xFFE6E6E6);
  static const Color mist = Color(0xFFF4F4F4);

  /// Pale tint of [accent] for selected chips and message bubbles.
  static const Color accentWash = Color(0xFFFFE8E0);
}
