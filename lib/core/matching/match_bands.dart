/// Colour bands for a compatibility percent.
///
/// Green is 70–100 (strong), yellow is 40–69 (partial), red is 0–39 (low).
/// A must-have miss uses [cappedStrength] so the colour stays red even when
/// the percent is high.
const matchStrongFloor = 70;
const matchPartialFloor = 40;

enum MatchStrength { strong, partial, low }

MatchStrength matchStrength(int percent) {
  if (percent >= matchStrongFloor) {
    return MatchStrength.strong;
  }
  if (percent >= matchPartialFloor) {
    return MatchStrength.partial;
  }
  return MatchStrength.low;
}

/// Must-have misses cap the colour at red. The percent itself stays visible.
MatchStrength cappedStrength(int percent, {required bool importantMismatch}) {
  if (importantMismatch) {
    return MatchStrength.low;
  }
  return matchStrength(percent);
}

String matchStrengthLabel(MatchStrength strength) => switch (strength) {
  MatchStrength.strong => 'Strong Match',
  MatchStrength.partial => 'Partial Match',
  MatchStrength.low => 'Low Match',
};

String matchColourName(MatchStrength strength) => switch (strength) {
  MatchStrength.strong => 'Green',
  MatchStrength.partial => 'Yellow',
  MatchStrength.low => 'Red',
};

String matchStrengthDetail(MatchStrength strength) => switch (strength) {
  MatchStrength.strong => 'Most of your priorities match.',
  MatchStrength.partial => 'Some preferences match. Still worth considering.',
  MatchStrength.low => 'Major preferences do not match.',
};
