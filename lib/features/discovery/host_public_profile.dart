import 'package:homizi/features/discovery/domain/listing.dart';

/// A lifestyle highlight on the public profile.
class HostQuality {
  const HostQuality({required this.id, required this.label});

  final String id;
  final String label;
}

/// A short note shown on the About tab for demo personas.
///
/// There is no reviews table. These lines are dummy copy for demo hosts only.
class HostReview {
  const HostReview({required this.quote, required this.by});

  final String quote;
  final String by;
}

/// Profile fields the page can already read.
///
/// `profiles.public_bio` is the bio. Lifestyle answers live on
/// `tenant_preferences.lifestyle` and `profile_details`, both owner-only, so
/// another person's row is not available here. Empty fields stay empty for
/// real accounts. Demo hosts fall back to [buildHostPublicStory].
class HostProfileFacts {
  const HostProfileFacts({
    this.bio = '',
    this.lifestyle = const [],
    this.languages = const [],
    this.smoking,
    this.food,
    this.pets,
    this.cleaning,
  });

  final String bio;
  final List<String> lifestyle;
  final List<String> languages;
  final String? smoking;
  final String? food;
  final String? pets;
  final String? cleaning;
}

/// What the public profile paints. [sampleBio] is true only for demo hosts
/// whose profile has no bio of its own.
class HostPublicStory {
  const HostPublicStory({
    required this.name,
    required this.occupation,
    required this.roleLabel,
    required this.city,
    required this.cities,
    required this.verified,
    required this.listingCount,
    required this.ratingLabel,
    required this.replyLabel,
    required this.bio,
    required this.sampleBio,
    required this.qualities,
    required this.languages,
    required this.matchPercent,
    required this.reviews,
  });

  final String name;
  final String occupation;
  final String roleLabel;
  final String city;
  final List<String> cities;
  final bool verified;
  final int listingCount;
  final String? ratingLabel;
  final String? replyLabel;
  final String bio;
  final bool sampleBio;
  final List<HostQuality> qualities;
  final List<String> languages;
  final int? matchPercent;
  final List<HostReview> reviews;
}

/// Hero tag shared by the listing host row and this profile.
String hostAvatarHeroTag(String hostUserId) => 'host-avatar-$hostUserId';

bool hostIsDemoPersona(String hostUserId) =>
    hostUserId.startsWith('demo-host-') || hostUserId.startsWith('demo-');

/// Owner, Tenant, Property Partner, or Home-Sharer.
String hostRoleLabel(String kind) {
  switch (kind.trim().toLowerCase()) {
    case 'tenant':
      return 'Tenant';
    case 'partner':
    case 'broker':
    case 'property partner':
      return 'Property Partner';
    case 'flatmate':
    case 'sharer':
    case 'home-sharer':
    case 'home sharer':
      return 'Home-Sharer';
    case 'owner':
    case 'host':
    case '':
      return 'Owner';
    default:
      return kind.trim();
  }
}

/// "2 hrs" from a measured reply time. Null when the host has no replies yet.
String? hostReplyLabel(int? hours) {
  if (hours == null || hours <= 0) {
    return null;
  }
  if (hours == 1) {
    return '1 hr';
  }
  if (hours < 24) {
    return '$hours hrs';
  }
  final days = (hours / 24).ceil();
  return days == 1 ? '1 day' : '$days days';
}

/// Homes posted by [listing]'s host, with the opened home first.
List<Listing> hostHomes(List<Listing> all, Listing listing) {
  final homes = <Listing>[];
  final seen = <String>{};
  for (final home in all) {
    if (home.hostUserId != listing.hostUserId || !seen.add(home.id)) {
      continue;
    }
    homes.add(home);
  }
  if (!homes.any((home) => home.id == listing.id)) {
    homes.insert(0, listing);
  }
  final anchor = homes.indexWhere((home) => home.id == listing.id);
  if (anchor > 0) {
    homes.insert(0, homes.removeAt(anchor));
  }
  return homes;
}

Listing hostAnchor(List<Listing> homes, Listing listing) {
  for (final home in homes) {
    if (home.id == listing.id) {
      return home;
    }
  }
  return listing;
}

/// Builds the profile from listings plus any profile fields the caller has.
///
/// Demo hosts with an empty bio get a fixed fallback. Real accounts do not.
HostPublicStory buildHostPublicStory({
  required Listing anchor,
  required List<Listing> homes,
  required bool signedIn,
  int? matchPercent,
  HostProfileFacts facts = const HostProfileFacts(),
}) {
  final shown = homes.isEmpty ? <Listing>[anchor] : homes;
  final demo = hostIsDemoPersona(anchor.hostUserId);
  final persona = _personas[anchor.hostUserId];
  final bio = facts.bio.trim();
  final sampleBio = bio.isEmpty && demo;
  final cities = <String>[];
  for (final home in shown) {
    final city = home.city.trim();
    if (city.isNotEmpty && !cities.contains(city)) {
      cities.add(city);
    }
  }
  final rating = demo
      ? (persona?.rating ?? _demoRating(anchor.hostUserId))
      : null;
  final reply =
      hostReplyLabel(anchor.replyWithinHours) ?? (demo ? 'Same day' : null);
  return HostPublicStory(
    name: anchor.hostDisplayName,
    occupation: anchor.hostOccupation.trim(),
    roleLabel: hostRoleLabel(anchor.hostKind),
    city: anchor.city.trim(),
    cities: cities,
    verified: anchor.hostVerified || anchor.trust.anyIdentity,
    listingCount: shown.length,
    ratingLabel: rating,
    replyLabel: reply,
    bio: sampleBio ? _demoBio(anchor, shown, persona) : bio,
    sampleBio: sampleBio,
    qualities: _qualities(shown, facts, demo: demo, persona: persona),
    languages: _languages(anchor, facts, demo: demo, persona: persona),
    matchPercent: signedIn ? matchPercent : null,
    reviews: demo ? (persona?.reviews ?? const []) : const [],
  );
}

String joinCities(List<String> cities) {
  if (cities.isEmpty) {
    return '';
  }
  if (cities.length == 1) {
    return cities.first;
  }
  if (cities.length == 2) {
    return '${cities[0]} and ${cities[1]}';
  }
  return '${cities.sublist(0, cities.length - 1).join(', ')}, and ${cities.last}';
}

const _qualityLabels = <String, String>{
  'non_smoker': 'Non-smoker',
  'vegetarian': 'Vegetarian',
  'early_riser': 'Early riser',
  'pet_friendly': 'Pet friendly',
  'quiet': 'Quiet',
  'working': 'Working professional',
  'clean': 'Clean & tidy',
  'night_owl': 'Night owl',
  'wfh': 'Works from home',
};

const _qualityOrder = <String>[
  'non_smoker',
  'vegetarian',
  'early_riser',
  'pet_friendly',
  'quiet',
  'working',
  'clean',
  'night_owl',
  'wfh',
];

const _lifestyleIds = <String, String>{
  'non_smoker': 'non_smoker',
  'pets_ok': 'pet_friendly',
  'early_riser': 'early_riser',
  'night_owl': 'night_owl',
  'wfh': 'wfh',
};

class _Persona {
  const _Persona({
    required this.bio,
    required this.rating,
    required this.languages,
    required this.extras,
    this.reviews = const [],
  });

  final String bio;
  final String rating;
  final List<String> languages;
  final List<String> extras;
  final List<HostReview> reviews;
}

/// Fixed fallback for demo hosts. Listing signals are applied first and a
/// persona never overrides them. Rohan stays "Rohan M.", product designer.
const _personas = <String, _Persona>{
  'demo-host-rohan': _Persona(
    bio:
        'Product designer in Bengaluru. I keep sunlit, tidy homes and reply the same day. Happy to walk you through Koramangala, Satellite, Vastrapur, or Adyar.',
    rating: '4.8',
    languages: ['English', 'Hindi', 'Kannada'],
    extras: ['early_riser', 'quiet', 'clean'],
    reviews: [
      HostReview(
        quote:
            'Rohan replied the same evening, and the Koramangala flat matched the photos.',
        by: 'Ananya S. · Bengaluru',
      ),
      HostReview(
        quote:
            'Clear about the deposit, and happy to show the home on a weekday.',
        by: 'Kabir N. · Ahmedabad',
      ),
    ],
  ),
};

const _demoExtras = ['early_riser', 'quiet', 'clean'];

List<HostQuality> _qualities(
  List<Listing> homes,
  HostProfileFacts facts, {
  required bool demo,
  required _Persona? persona,
}) {
  final picked = <String>{};
  void add(String? id) {
    if (id == null || !_qualityLabels.containsKey(id)) {
      return;
    }
    picked.add(id);
  }

  for (final item in facts.lifestyle) {
    add(_lifestyleIds[item]);
  }
  final smoking = facts.smoking?.trim();
  if (smoking == 'No') {
    add('non_smoker');
  }
  final food = facts.food?.trim();
  if (food == 'Veg') {
    add('vegetarian');
  }
  final pets = facts.pets?.trim();
  if (pets == 'Allowed') {
    add('pet_friendly');
  }
  final cleaning = facts.cleaning?.trim();
  if (cleaning == 'Myself' || cleaning == 'Shared cleaning') {
    add('clean');
  }
  for (final home in homes) {
    for (final rule in home.restrictions) {
      final text = rule.toLowerCase();
      if (text.contains('smok') &&
          (text.contains('no') || text.contains('non'))) {
        add('non_smoker');
      }
      if (text.contains('quiet')) {
        add('quiet');
      }
    }
    for (final line in home.suitability) {
      if (line.toLowerCase().contains('working')) {
        add('working');
      }
    }
    if (home.petsAllowed) {
      add('pet_friendly');
    }
  }

  final suppress = <String>{};
  if (smoking == 'Yes' || smoking == 'Occasional') {
    suppress.add('non_smoker');
  }
  if (food == 'Non-Veg' || food == 'Both') {
    suppress.add('vegetarian');
  }
  if (pets == 'Not Allowed') {
    suppress.add('pet_friendly');
  }
  picked.removeAll(suppress);

  if (demo && picked.length < 6) {
    for (final id in persona?.extras ?? _demoExtras) {
      if (picked.length >= 6 || suppress.contains(id)) {
        continue;
      }
      add(id);
    }
  }

  return [
    for (final id in _qualityOrder)
      if (picked.contains(id)) HostQuality(id: id, label: _qualityLabels[id]!),
  ];
}

List<String> _languages(
  Listing anchor,
  HostProfileFacts facts, {
  required bool demo,
  required _Persona? persona,
}) {
  final given = [
    for (final language in facts.languages)
      if (language.trim().isNotEmpty) language.trim(),
  ];
  if (given.isNotEmpty) {
    return given;
  }
  if (!demo) {
    return const [];
  }
  if (persona != null) {
    return persona.languages;
  }
  return _demoLanguages(anchor.city);
}

List<String> _demoLanguages(String city) {
  final regional = switch (city.trim()) {
    'Bengaluru' => 'Kannada',
    'Ahmedabad' => 'Gujarati',
    'Mumbai' || 'Pune' => 'Marathi',
    'Chennai' => 'Tamil',
    'Hyderabad' => 'Telugu',
    'Kolkata' => 'Bengali',
    _ => 'Hindi',
  };
  if (regional == 'Hindi') {
    return const ['English', 'Hindi'];
  }
  return ['English', 'Hindi', regional];
}

String _demoBio(Listing anchor, List<Listing> homes, _Persona? persona) {
  final written = persona?.bio.trim() ?? '';
  if (written.isNotEmpty) {
    return written;
  }
  final job = anchor.hostOccupation.trim();
  final city = anchor.city.trim();
  final who = job.isEmpty ? 'I list homes on Homizi' : '$job on Homizi';
  final where = city.isEmpty ? '' : ' in $city';
  final places = <String>[];
  for (final home in homes) {
    final place = home.locality.trim();
    if (place.isNotEmpty && !places.contains(place) && places.length < 3) {
      places.add(place);
    }
  }
  final homesLine = places.isEmpty ? '' : ' Homes in ${joinCities(places)}.';
  return '$who$where.$homesLine I reply on Homizi. The phone number stays off this profile.';
}

String _demoRating(String hostUserId) {
  const bands = ['4.6', '4.7', '4.8', '4.9'];
  final sum = hostUserId.codeUnits.fold<int>(0, (total, unit) => total + unit);
  return bands[sum % bands.length];
}
