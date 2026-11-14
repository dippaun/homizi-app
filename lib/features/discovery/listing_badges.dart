import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/published_search.dart';

/// Trust badges for one listing. The card and the detail screen both read
/// these, so a badge on the card is always on the screen it opens.
class ListingBadges {
  const ListingBadges({
    required this.verified,
    required this.verifiedListing,
    required this.hostVerified,
    required this.photosVerified,
  });

  /// Host identity is verified (KYC or Aadhaar / face check).
  final bool verified;
  final bool verifiedListing;
  final bool hostVerified;
  final bool photosVerified;
}

ListingBadges listingBadges(Listing listing, {PublishedHome? published}) {
  return ListingBadges(
    verified: listing.hostVerified || listing.trust.anyIdentity,
    verifiedListing: listing.listingVerified,
    hostVerified: listing.hostVerified || published != null,
    photosVerified: published?.photosVerified ?? listing.listingVerified,
  );
}
