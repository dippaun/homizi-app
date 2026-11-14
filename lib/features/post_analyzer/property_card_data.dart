import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/post_analyzer/property_match_adapter.dart';
import 'package:homizi/shared/widgets/homizi_property_card.dart';

/// Kinds the property card shows, in the spec order.
const propertyNearbyKinds = <String>[
  'metro',
  'station',
  'train',
  'supermarket',
  'hospital',
  'gym',
];

HomiziPropertyCardData propertyCardData({
  required Listing listing,
  required PropertyMatchScore score,
  required bool saved,
  String? commuteLabel,
  List<HomiziNearbyPlace>? nearby,
}) {
  return HomiziPropertyCardData(
    id: listing.id,
    title: listing.title,
    place: '${listing.locality}, ${listing.city}',
    rentLabel: '${formatInr(listing.rentInr)} / month',
    matchPercent: score.percent,
    verifiedListing: listing.listingVerified,
    saved: saved,
    photos: [
      for (var i = 0; i < listing.photoAssets.length; i++)
        HomiziPropertyPhoto(
          ref: listing.photoAssets[i],
          caption: i == 0 ? 'Room (Main Photo)' : 'Room',
        ),
    ],
    details: _details(listing),
    amenities: _amenities(listing),
    topReasons: score.topReasons,
    hostName: listing.hostDisplayName,
    hostAvatarRef: _avatar(listing),
    hostVerified: listing.hostVerified,
    hostIdentityVerified: listing.trust.anyIdentity,
    hostRole: listing.hostKind.trim(),
    responseLabel: _response(listing.replyWithinHours),
    nearby: nearby ?? _nearby(listing.nearbyPlaces),
    commuteLabel: commuteLabel,
  );
}

List<HomiziPropertyDetail> _details(Listing listing) {
  final details = <HomiziPropertyDetail>[
    HomiziPropertyDetail(
      icon: HomiziDetailIcon.room,
      label: _roomType(listing),
    ),
  ];
  final bhk = _bhk(listing);
  if (bhk.isNotEmpty &&
      bhk.toLowerCase() != details.first.label.toLowerCase()) {
    details.add(HomiziPropertyDetail(icon: HomiziDetailIcon.bhk, label: bhk));
  }
  final area = listing.areaSqft;
  if (area != null && area > 0) {
    details.add(
      HomiziPropertyDetail(
        icon: HomiziDetailIcon.area,
        label: formatSqft(area),
      ),
    );
  }
  final floor = listing.floorNo;
  if (floor != null) {
    details.add(
      HomiziPropertyDetail(
        icon: HomiziDetailIcon.floor,
        label: '${_ordinal(floor)} Floor',
      ),
    );
  }
  return details;
}

String _roomType(Listing listing) {
  final raw = listing.propertyTypeLabel;
  return raw
      .split(' ')
      .map((word) {
        if (word.isEmpty) {
          return word;
        }
        if (word.toUpperCase() == 'BHK') {
          return 'BHK';
        }
        return '${word[0].toUpperCase()}${word.substring(1)}';
      })
      .join(' ');
}

String _bhk(Listing listing) {
  if (listing.propertyType == 'studio' || listing.bedrooms <= 0) {
    return listing.propertyType == 'studio' ? 'Studio' : '';
  }
  return '${listing.bedrooms}BHK';
}

List<String> _amenities(Listing listing) {
  final chips = <String>[listing.furnishingLabel];
  for (final name in listing.amenities) {
    final label = name.trim();
    if (label.isEmpty) {
      continue;
    }
    if (label.toLowerCase() == 'wifi') {
      chips.add('WiFi');
    } else {
      chips.add(label);
    }
  }
  if (listing.restrictions.any(
    (item) => item.toLowerCase().contains('smoking'),
  )) {
    chips.add('No Smoking');
  }
  if (listing.preferredTenants.contains('bachelors')) {
    chips.add('Bachelor Friendly');
  }
  final unique = <String>[];
  for (final chip in chips) {
    if (!unique.contains(chip)) {
      unique.add(chip);
    }
  }
  return unique.take(6).toList();
}

List<HomiziNearbyPlace> _nearby(List<ListingNearby> places) {
  final shown = <HomiziNearbyPlace>[];
  for (final kind in propertyNearbyKinds) {
    if (kind == 'train') {
      continue;
    }
    ListingNearby? match;
    for (final place in places) {
      final saved = place.kind.toLowerCase();
      final wanted = kind == 'station'
          ? (saved == 'station' || saved == 'train')
          : saved == kind;
      if (wanted && place.km > 0) {
        match = place;
        break;
      }
    }
    if (match == null) {
      continue;
    }
    shown.add(
      HomiziNearbyPlace(
        kind: kind,
        label: _nearbyLabel(kind),
        distanceLabel: _km(match.km),
      ),
    );
  }
  return shown;
}

String _nearbyLabel(String kind) => switch (kind) {
  'metro' => 'Metro',
  'station' || 'train' => 'Station',
  'supermarket' => 'Supermarket',
  'hospital' => 'Hospital',
  'gym' => 'Gym',
  _ => kind,
};

String _km(double km) {
  final fixed = km.toStringAsFixed(1);
  final text = fixed.endsWith('.0')
      ? fixed.substring(0, fixed.length - 2)
      : fixed;
  return '$text km';
}

String? _response(int? hours) {
  if (hours == null || hours <= 0) {
    return null;
  }
  if (hours == 1) {
    return 'Responds within 1 hour';
  }
  return 'Responds within $hours hours';
}

/// A known name uses the portrait that matches that person. Other hosts
/// keep the portrait saved on the listing. Unknown names stay as initials.
String? _avatar(Listing listing) {
  final named = _namedPortraits[listing.hostDisplayName.trim().toLowerCase()];
  if (named != null) {
    return named;
  }
  final saved = listing.hostAvatarUrl?.trim();
  if (saved != null && saved.isNotEmpty) {
    return saved;
  }
  return null;
}

const _namedPortraits = <String, String>{
  'rohan s.': 'assets/avatars/avatar_04.webp',
  'rohan m.': 'assets/avatars/avatar_04.webp',
  'meera k.': 'assets/avatars/avatar_01.webp',
  'kabir n.': 'assets/avatars/avatar_02.webp',
  'neha sharma': 'assets/avatars/avatar_03.webp',
  'imran q.': 'assets/avatars/avatar_02.webp',
};

String _ordinal(int floor) {
  final mod100 = floor % 100;
  if (mod100 >= 11 && mod100 <= 13) {
    return '${floor}th';
  }
  return switch (floor % 10) {
    1 => '${floor}st',
    2 => '${floor}nd',
    3 => '${floor}rd',
    _ => '${floor}th',
  };
}
