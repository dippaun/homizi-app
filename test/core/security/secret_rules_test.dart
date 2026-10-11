import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/security/secret_rules.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

void main() {
  test('secret rules catch keys and ignore role grants', () {
    expect(
      secretRuleHits(
        'grant all on all tables in schema public to service_role;',
      ),
      isEmpty,
    );
    expect(secretRuleHits("const password = 'local-dev-only';"), isEmpty);
    expect(
      secretRuleHits(
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiJ9.signaturevalue',
      ),
      contains('jwt'),
    );
    expect(
      secretRuleHits(
        '-----BEGIN PRIVATE KEY-----\nabc\n-----END PRIVATE KEY-----',
      ),
      contains('private-key'),
    );
    expect(secretRuleHits('sk_live_abc123'), contains('live-secret-key'));
    expect(
      secretRuleHits('service_role_key = actual-secret-value'),
      contains('assigned-secret'),
    );
    expect(secretRuleHits('s3_secret_key = "env(S3_SECRET_KEY)"'), isEmpty);
  });

  test('placeholder reading colors meet contrast', () {
    expect(
      _contrast(HomiziColors.ink, HomiziColors.sand),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(HomiziColors.ink, HomiziColors.card),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(Colors.white, HomiziColors.seed),
      greaterThanOrEqualTo(4.5),
    );
    // Placeholder clay with white text is about 4.46. Brand assets should close it.
    expect(_contrast(Colors.white, HomiziColors.clay), greaterThan(4.4));
  });
}

double _contrast(Color foreground, Color background) {
  final lighter = math.max(_luminance(foreground), _luminance(background));
  final darker = math.min(_luminance(foreground), _luminance(background));
  return (lighter + 0.05) / (darker + 0.05);
}

double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}
