import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// A published shared home is already a public roommate-seeker profile.
///
/// Full-house owners stay off this list. A flatmate, home-sharer, private
/// room, shared room, or PG is someone who shared access to their home.
bool listingSharesHome(Listing listing) {
  final type = listing.propertyType.trim().toLowerCase();
  if (type == 'shared_room' || type == 'pg' || type == 'private_room') {
    return true;
  }
  final kind = listing.hostKind.trim().toLowerCase();
  return kind.contains('flatmate') ||
      kind.contains('sharer') ||
      kind.contains('roommate');
}

/// One seeker per host. The card uses the home's city, locality, and rent.
List<FinderPerson> seekersFromSharedHomes(
  List<Listing> listings, {
  String selfUserId = '',
}) {
  final people = <FinderPerson>[];
  final seen = <String>{};
  for (final listing in listings) {
    if (!listingSharesHome(listing)) {
      continue;
    }
    final host = listing.hostUserId.trim();
    if (host.isEmpty || host == selfUserId || !seen.add(host)) {
      continue;
    }
    final name = listing.hostDisplayName.trim();
    if (name.isEmpty) {
      continue;
    }
    people.add(_person(listing));
  }
  return people;
}

FinderPerson _person(Listing listing) {
  final women = _wants(listing, const ['female', 'women', 'woman']);
  final men = _wants(listing, const ['male', 'men', 'man', 'bachelors']);
  final gender = women && !men
      ? 'woman'
      : men && !women
      ? 'man'
      : '';
  final photo = listing.hostAvatarUrl?.trim() ?? '';
  final gallery = listing.photoAssets;
  return FinderPerson(
    seeker: RoommateSeeker(
      id: 'share-${listing.hostUserId}',
      name: listing.hostDisplayName.trim(),
      age: 0,
      profession: listing.hostOccupation.trim().isEmpty
          ? 'Home-Sharer'
          : listing.hostOccupation.trim(),
      photoRef: photo.isEmpty
          ? (gallery.isEmpty ? null : gallery.first)
          : photo,
      trust: const UserBadges(),
      traits: RoommateTraits(
        city: listing.city,
        localities: [
          if (listing.locality.trim().isNotEmpty) listing.locality.trim(),
        ],
        budgetMinInr: listing.rentInr,
        budgetMaxInr: listing.rentInr,
        gender: gender.isEmpty ? null : gender,
        occupancy: 'shared',
        food: listing.nonVegAllowed ? 'non_veg' : 'veg',
        smoking:
            listing.restrictions.any(
              (item) => item.toLowerCase().contains('smok'),
            )
            ? 'never'
            : null,
        pets: listing.petsAllowed ? 'ok' : 'none',
      ),
    ),
    group: 'Home-Sharer',
    field: listing.hostOccupation.trim().isEmpty
        ? 'Shared home'
        : listing.hostOccupation.trim(),
    drinking: '',
    lookingFor: listing.bhkLabel,
    education: '',
    hometown: '',
    about: listing.summary,
    gallery: gallery,
    fromSharedHome: true,
  );
}

bool _wants(Listing listing, List<String> keys) {
  final have = listing.preferredTenants.map((item) => item.toLowerCase());
  return keys.any(have.contains);
}
