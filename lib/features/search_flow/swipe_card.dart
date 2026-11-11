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
}
