import 'package:homizi/features/listings/domain/listing_draft.dart' as draft;

/// Owner-editable nearby row for the list-a-home step.
///
/// Field names match the shared nearby service landing in
/// `lib/features/nearby/` (`category`, `name`, `distanceKm`, `minutes`).
/// The listing wizard maps these onto the saved draft rows. When that
/// folder is on main, swap this type for the shared one.
class NearbyPlace {
  const NearbyPlace({
    required this.category,
    required this.name,
    this.distanceKm,
    this.minutes,
  });

  /// metro, train, bus, airport, hospital, supermarket, mall, movie, or gym.
  final String category;
  final String name;
  final double? distanceKm;
  final int? minutes;

  bool get hasDistance =>
      distanceKm != null && minutes != null && distanceKm! >= 0 && minutes! > 0;

  factory NearbyPlace.fromDraft(draft.NearbyPlace place) {
    return NearbyPlace(
      category: place.kind,
      name: place.name,
      distanceKm: place.km,
      minutes: place.minutes,
    );
  }

  draft.NearbyPlace toDraft() {
    return draft.NearbyPlace(
      kind: category,
      name: name,
      km: distanceKm,
      minutes: minutes,
    );
  }

  NearbyPlace copyWith({
    String? name,
    double? distanceKm,
    int? minutes,
    bool setDistance = false,
  }) {
    return NearbyPlace(
      category: category,
      name: name ?? this.name,
      distanceKm: setDistance ? distanceKm : (distanceKm ?? this.distanceKm),
      minutes: setDistance ? minutes : (minutes ?? this.minutes),
    );
  }
}
