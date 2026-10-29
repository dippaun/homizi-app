import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';

double _contrast(Color a, Color b) {
  final lighter = math.max(a.computeLuminance(), b.computeLuminance());
  final darker = math.min(a.computeLuminance(), b.computeLuminance());
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('keyboard focus draws an ink ring on buttons', () {
    final theme = HomiziTheme.light();
    for (final style in [
      theme.filledButtonTheme.style!,
      theme.outlinedButtonTheme.style!,
      theme.textButtonTheme.style!,
      theme.iconButtonTheme.style!,
    ]) {
      final side = style.side!.resolve({WidgetState.focused});
      expect(side, isNotNull);
      expect(side!.width, greaterThanOrEqualTo(3));
      expect(side.color, HomiziColors.ink);
    }
    expect(theme.focusColor, HomiziColors.ink);
  });

  test('light pairs clear WCAG AA and orange labels stay near-black', () {
    expect(_contrast(HomiziColors.ink, HomiziColors.white), greaterThan(4.5));
    expect(
      _contrast(HomiziColors.inkSoft, HomiziColors.white),
      greaterThan(4.5),
    );
    expect(_contrast(HomiziColors.muted, HomiziColors.white), greaterThan(4.5));
    expect(_contrast(HomiziColors.ink, HomiziColors.accent), greaterThan(4.5));
    expect(
      _contrast(HomiziColors.ink, HomiziColors.accentWash),
      greaterThan(4.5),
    );
    expect(_contrast(HomiziColors.white, HomiziColors.accent), lessThan(4.5));

    final light = HomiziTheme.light();
    expect(light.useMaterial3, isTrue);
    expect(light.colorScheme.primary, HomiziColors.accent);
    expect(light.colorScheme.onPrimary, HomiziColors.ink);
    expect(light.colorScheme.surface, HomiziColors.white);
    expect(light.scaffoldBackgroundColor, HomiziColors.soft);
  });

  test('dark pairs stay readable and the accent label stays near-black', () {
    expect(
      _contrast(HomiziColors.nightInk, HomiziColors.night),
      greaterThan(4.5),
    );
    expect(
      _contrast(HomiziColors.nightMuted, HomiziColors.night),
      greaterThan(4.5),
    );
    expect(
      _contrast(HomiziColors.nightInk, HomiziColors.nightRaised),
      greaterThan(4.5),
    );
    expect(
      _contrast(HomiziColors.nightMuted, HomiziColors.nightRaised),
      greaterThan(4.5),
    );
    expect(
      _contrast(HomiziColors.accentWash, HomiziColors.nightAccentContainer),
      greaterThan(4.5),
    );
    expect(_contrast(HomiziColors.ink, HomiziColors.accent), greaterThan(4.5));

    final dark = HomiziTheme.dark();
    expect(dark.useMaterial3, isTrue);
    expect(dark.colorScheme.brightness, Brightness.dark);
    expect(dark.colorScheme.primary, HomiziColors.accent);
    expect(dark.colorScheme.onPrimary, HomiziColors.ink);
    expect(dark.colorScheme.surface, HomiziColors.night);
    expect(dark.colorScheme.onSurface, HomiziColors.nightInk);
    expect(dark.scaffoldBackgroundColor, HomiziColors.night);
  });

  test('the accent stays logo orange and supporting pairs stay readable', () {
    expect(HomiziColors.accent, HomiziColors.brandOrange);
    expect(HomiziColors.brandYellow, const Color(0xFFFFD20A));
    expect(HomiziColors.ink, const Color(0xFF172033));
    expect(HomiziColors.soft, const Color(0xFFF7F8FA));
    expect(HomiziColors.success, const Color(0xFF16803C));
    expect(HomiziColors.warning, const Color(0xFF9A6700));
    expect(HomiziColors.error, const Color(0xFFB42318));
    expect(
      _contrast(HomiziColors.white, HomiziColors.brandYellow),
      lessThan(4.5),
    );
    expect(
      _contrast(HomiziColors.white, HomiziColors.brandGolden),
      lessThan(4.5),
    );
    expect(
      _contrast(HomiziColors.ink, HomiziColors.brandYellow),
      greaterThan(4.5),
    );
    expect(
      _contrast(HomiziColors.ink, HomiziColors.brandGolden),
      greaterThan(4.5),
    );
    expect(
      _contrast(HomiziColors.onSuccess, HomiziColors.success),
      greaterThan(4.5),
    );
    expect(
      _contrast(HomiziColors.onWarning, HomiziColors.warning),
      greaterThan(4.5),
    );
    expect(
      _contrast(HomiziColors.onError, HomiziColors.error),
      greaterThan(4.5),
    );
    expect(_contrast(HomiziColors.ink, HomiziColors.mist), greaterThan(4.5));
    expect(
      _contrast(HomiziColors.inkSoft, HomiziColors.mist),
      greaterThan(4.5),
    );
    expect(_contrast(HomiziColors.muted, HomiziColors.mist), greaterThan(4.5));
    expect(
      _contrast(HomiziColors.nightInk, HomiziColors.nightAccentContainer),
      greaterThan(4.5),
    );

    final light = HomiziTheme.light();
    expect(
      _contrast(light.colorScheme.error, HomiziColors.white),
      greaterThan(4.5),
    );
    expect(
      _contrast(light.colorScheme.onError, light.colorScheme.error),
      greaterThan(4.5),
    );
    expect(light.colorScheme.primary, HomiziColors.brandOrange);
  });
}
