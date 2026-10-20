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
    expect(light.scaffoldBackgroundColor, HomiziColors.white);
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
    expect(HomiziColors.accent, const Color(0xFFF75620));
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
    expect(light.colorScheme.primary, const Color(0xFFF75620));
  });
}
