import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/priorities/host_seeker_score.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';
import 'package:homizi/features/seekers/seeker_score.dart';

class SeekerListFilter {
  const SeekerListFilter({
    this.verifiedOnly = false,
    this.budgetFits = false,
    this.profession = 'any',
  });

  final bool verifiedOnly;
  final bool budgetFits;

  /// `any`, `working`, or `student`.
  final String profession;

  bool get isDefault => !verifiedOnly && !budgetFits && profession == 'any';

  SeekerListFilter copyWith({
    bool? verifiedOnly,
    bool? budgetFits,
    String? profession,
  }) {
    return SeekerListFilter(
      verifiedOnly: verifiedOnly ?? this.verifiedOnly,
      budgetFits: budgetFits ?? this.budgetFits,
      profession: profession ?? this.profession,
    );
  }
}

class ScoredSeeker {
  const ScoredSeeker({
    required this.profile,
    required this.fit,
    this.priorityMatch,
  });

  final SeekerPublicProfile profile;
  final SeekerFit fit;

  /// Set when the host saved a preferred tenant profile. [fit] comes from it.
  final HostPriorityMatch? priorityMatch;

  /// "Top matches": strong and no must-have missed.
  bool get isTopMatch =>
      fit.percent >= matchStrongFloor &&
      !(priorityMatch?.missesMustHave ?? false);
}

enum SeekerTab { all, best, shortlisted }

List<HostProperty> collectHostProperties({
  required Iterable<DemoOwnedHome> owned,
  required Iterable<PublishedHome> published,
}) {
  final byId = <String, HostProperty>{};
  for (final home in owned) {
    if (home.id.isEmpty || home.draft.city.trim().isEmpty) {
      continue;
    }
    byId[home.id] = hostPropertyFromDraft(home.draft);
  }
  for (final home in published) {
    byId[home.listing.id] = hostPropertyFromListing(
      home.listing,
      justPublished: true,
    );
  }
  if (byId.isEmpty) {
    return sampleHostProperties;
  }
  final rows = byId.values.toList()
    ..sort((a, b) {
      final city = a.city.compareTo(b.city);
      if (city != 0) {
        return city;
      }
      return a.label.compareTo(b.label);
    });
  return rows;
}

String preferredPropertyId(List<HostProperty> all, {String? queryId}) {
  if (queryId != null && all.any((item) => item.id == queryId)) {
    return queryId;
  }
  for (final item in all) {
    if (item.justPublished) {
      return item.id;
    }
  }
  if (all.any((item) => item.id == 'demo-own-koramangala')) {
    return 'demo-own-koramangala';
  }
  if (all.any((item) => item.id == 'sample-bengaluru-2bhk')) {
    return 'sample-bengaluru-2bhk';
  }
  return all.first.id;
}

HostProperty propertyInCity(List<HostProperty> all, String city) {
  final rows = [
    for (final item in all)
      if (sameSeekerCity(item.city, city)) item,
  ];
  if (rows.isEmpty) {
    return all.first;
  }
  for (final item in rows) {
    final label = item.label.toLowerCase();
    if (label.startsWith('2 bhk')) {
      return item;
    }
  }
  return rows.first;
}

List<ScoredSeeker> scoreSeekers({
  required List<SeekerPublicProfile> seekers,
  required HostProperty property,
  required SeekerListFilter filter,
  required Set<String> dismissed,
  HostPriorities? priorities,
  LearnedSignals signals = LearnedSignals.empty,
  HostTenantPriorities? hostPriorities,
}) {
  final ranked = hostPriorities != null && hostPriorities.saved
      ? hostPriorities
      : null;
  final rows = <ScoredSeeker>[];
  for (final profile in seekers) {
    if (dismissed.contains(profile.id)) {
      continue;
    }
    if (!sameSeekerCity(profile.city, property.city)) {
      continue;
    }
    // Saved Set My Priorities decide the %. Otherwise the listing's own
    // implied ranks do.
    final priorityMatch = ranked == null
        ? null
        : scoreSeekerWithHostPriorities(
            priorities: ranked,
            seeker: profile,
            property: property,
          );
    final fit =
        priorityMatch?.fit ??
        scoreSeekerForProperty(
          property: property,
          seeker: profile,
          priorities: priorities,
          signals: signals,
        );
    if (priorityMatch == null && seekerBlockedByHardFilter(priorities, fit)) {
      continue;
    }
    if (filter.verifiedOnly && !profile.verified) {
      continue;
    }
    if (filter.budgetFits && !budgetCoversRent(property, profile)) {
      continue;
    }
    if (filter.profession != 'any' && profile.profession != filter.profession) {
      continue;
    }
    rows.add(
      ScoredSeeker(profile: profile, fit: fit, priorityMatch: priorityMatch),
    );
  }
  rows.sort((a, b) {
    final byScore = b.fit.percent.compareTo(a.fit.percent);
    if (byScore != 0) {
      return byScore;
    }
    return a.profile.name.compareTo(b.profile.name);
  });
  return rows;
}

List<ScoredSeeker> seekersForTab(
  List<ScoredSeeker> rows,
  SeekerTab tab,
  Set<String> shortlisted,
) {
  return switch (tab) {
    SeekerTab.all => rows,
    SeekerTab.best => [
      for (final row in rows)
        if (row.fit.percent >= matchStrongFloor) row,
    ],
    SeekerTab.shortlisted => [
      for (final row in rows)
        if (shortlisted.contains(row.profile.id)) row,
    ],
  };
}
