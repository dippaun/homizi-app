import 'package:flutter/material.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/widgets/match_score.dart';

/// Fixed clock for demo freshness so a rebuild does not reshuffle scores.
final flowScoreToday = DateTime.utc(2026, 10, 29);

/// Likes, skips, saves, visits, verification, listing quality, and freshness.
///
/// Verification still shows as its own badges. These flags only adjust the
/// percent. They are not the percent.
class EngagementSignals {
  const EngagementSignals({
    this.likes = 0,
    this.skips = 0,
    this.saves = 0,
    this.visits = 0,
    this.identityVerified = false,
    this.ownershipVerified = false,
    this.photoVerified = false,
    this.quality = 0,
    this.ageDays = 30,
  });

  final int likes;
  final int skips;
  final int saves;
  final int visits;
  final bool identityVerified;
  final bool ownershipVerified;
  final bool photoVerified;

  /// 0–10. Photos and completed detail.
  final int quality;

  /// Days since the card was published or updated.
  final int ageDays;
}

class FlowScore {
  const FlowScore({
    required this.percent,
    required this.reasons,
    required this.importantMismatch,
  });

  final int percent;
  final List<String> reasons;
  final bool importantMismatch;
}

/// Stable demo activity so the same card always explains the same number.
EngagementSignals signalsFor(
  String id, {
  required bool identityVerified,
  bool ownershipVerified = false,
  required bool photoVerified,
  required int quality,
  required int ageDays,
}) {
  final hash = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  return EngagementSignals(
    likes: hash % 5,
    skips: hash % 3,
    saves: hash % 2,
    visits: (hash ~/ 3) % 4,
    identityVerified: identityVerified,
    ownershipVerified: ownershipVerified,
    photoVerified: photoVerified,
    quality: quality,
    ageDays: ageDays,
  );
}

int listingAgeDays(String? publishedAtIso, DateTime now) {
  if (publishedAtIso == null || publishedAtIso.length < 10) {
    return 21;
  }
  final date = DateTime.tryParse(publishedAtIso.substring(0, 10));
  if (date == null) {
    return 21;
  }
  final days = now.difference(date).inDays;
  if (days < 0) {
    return 0;
  }
  return days;
}

/// Adds engagement on top of a base match. A key miss keeps [percent] and
/// forces the colour to red via [matchFill].
FlowScore combineScore({
  required int base,
  required List<String> reasons,
  required bool importantMismatch,
  required EngagementSignals signals,
}) {
  final lines = <String>[
    if (importantMismatch) 'Key requirement does not match.',
    ...reasons,
  ];
  var delta = 0;

  void add(int points, String line) {
    if (points == 0) {
      return;
    }
    delta += points;
    lines.add(line);
  }

  final likePoints = (signals.likes * 2).clamp(0, 8);
  add(likePoints, '${signals.likes} likes (+$likePoints)');
  final skipPoints = (signals.skips * 3).clamp(0, 12);
  add(-skipPoints, '${signals.skips} skips (-$skipPoints)');
  final savePoints = (signals.saves * 3).clamp(0, 6);
  add(savePoints, '${signals.saves} saves (+$savePoints)');
  final visitPoints = (signals.visits * 4).clamp(0, 8);
  add(visitPoints, '${signals.visits} visits (+$visitPoints)');
  if (signals.identityVerified) {
    add(4, 'Identity verified (+4)');
  }
  if (signals.ownershipVerified) {
    add(3, 'Ownership or authorisation checked (+3)');
  }
  if (signals.photoVerified) {
    add(3, 'Photos checked (+3)');
  }
  if (signals.quality >= 8) {
    add(6, 'Strong listing detail (+6)');
  } else if (signals.quality >= 5) {
    add(3, 'Listing detail (+3)');
  }
  if (signals.ageDays <= 7) {
    add(6, 'Listed this week (+6)');
  } else if (signals.ageDays <= 21) {
    add(3, 'Recently listed (+3)');
  } else if (signals.ageDays > 60) {
    add(-4, 'Older listing (-4)');
  }

  final percent = (base + delta).clamp(0, 100);
  return FlowScore(
    percent: percent,
    reasons: lines,
    importantMismatch: importantMismatch,
  );
}

/// Green at 70% or more, yellow from 40% to 69%, red below 40%.
/// A key-requirement miss is red even when the percent is higher.
({Color background, Color foreground}) matchFill(
  int percent, {
  required bool importantMismatch,
}) {
  final strength = cappedStrength(
    percent,
    importantMismatch: importantMismatch,
  );
  final tone = switch (strength) {
    MatchStrength.strong => matchTone(matchStrongFloor),
    MatchStrength.partial => matchTone(matchPartialFloor),
    MatchStrength.low => matchTone(0),
  };
  return (background: tone.background, foreground: tone.foreground);
}
