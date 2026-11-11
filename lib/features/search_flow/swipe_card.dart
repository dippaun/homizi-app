enum SwipeDecision { like, skip, save }

enum FlowBadge { identity, ownership, photo }

/// One card in the shared property and people decks.
class SwipeMatchCardData {
  const SwipeMatchCardData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.photoAsset,
    required this.percent,
    required this.importantMismatch,
    required this.reasons,
    required this.badges,
    this.highlights = const [],
    this.facts = const [],
    this.portrait = false,
  });

  final String id;
  final String title;
  final String subtitle;
  final String meta;
  final String photoAsset;
  final int percent;
  final bool importantMismatch;
  final List<String> reasons;
  final List<FlowBadge> badges;

  /// Short chips on the card. The full [reasons] list stays in the breakdown.
  final List<String> highlights;

  /// Up to four facts painted on the card. Score reasons stay in [reasons].
  final List<String> facts;

  /// Face photo. Alignment keeps the whole face in frame.
  final bool portrait;
}

/// Up to [limit] story lines. Engagement deltas such as "2 likes (+4)" stay
/// in the breakdown sheet.
List<String> compactSwipeReasons(List<String> reasons, {int limit = 3}) {
  final story = <String>[];
  for (final reason in reasons) {
    final line = reason.trim();
    if (line.isEmpty || _engagementLine.hasMatch(line)) {
      continue;
    }
    story.add(line);
    if (story.length == limit) {
      break;
    }
  }
  if (story.isNotEmpty) {
    return story;
  }
  return reasons.take(limit).toList();
}

final _engagementLine = RegExp(r'\([+-]\d+\)$');
