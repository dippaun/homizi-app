import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/compatibility.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roles/requirement_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/features/search_flow/flow_score.dart';
import 'package:homizi/features/search_flow/listing_rank.dart';
import 'package:homizi/features/search_flow/swipe_card.dart';

class _Offer {
  const _Offer({
    required this.city,
    required this.locality,
    required this.rent,
    required this.furnishing,
    required this.amenities,
    required this.propertyType,
  });

  final String city;
  final String locality;
  final int rent;
  final String furnishing;
  final List<String> amenities;
  final String propertyType;
}

const _sampleOffer = _Offer(
  city: 'Bengaluru',
  locality: 'Koramangala',
  rent: 28000,
  furnishing: 'semi_furnished',
  amenities: ['wifi', 'ac', 'security'],
  propertyType: 'apartment',
);

class _Demand {
  _Demand({
    required this.id,
    required this.name,
    required this.city,
    required this.localities,
    required this.budgetMin,
    required this.budgetMax,
    required this.roomType,
    required this.furnishing,
    required this.amenities,
    required this.about,
    required this.profession,
    required this.moveIn,
    required this.avatar,
  });

  final String id;
  final String name;
  final String city;
  final List<String> localities;
  final int budgetMin;
  final int budgetMax;
  final String roomType;
  final String furnishing;
  final List<String> amenities;
  final String about;
  final String profession;
  final DateTime moveIn;
  final String avatar;
}

final _demands = <_Demand>[
  _Demand(
    id: 'meera',
    name: 'Meera Krishnan',
    city: 'Bengaluru',
    localities: ['Koramangala', 'Indiranagar'],
    budgetMin: 20000,
    budgetMax: 35000,
    roomType: '2bhk',
    furnishing: 'semi_furnished',
    amenities: ['wifi', 'washing_machine'],
    about: 'Product designer at a Koramangala studio. Vegetarian, no smoking.',
    profession: 'Working',
    moveIn: DateTime.utc(2026, 12),
    avatar: 'assets/avatars/avatar_02.webp',
  ),
  _Demand(
    id: 'arjun',
    name: 'Arjun Nair',
    city: 'Bengaluru',
    localities: ['HSR Layout', 'Bellandur'],
    budgetMin: 15000,
    budgetMax: 24000,
    roomType: '1bhk',
    furnishing: 'furnished',
    amenities: ['wifi', 'power_backup'],
    about: 'Software engineer. Needs a desk and a quiet block.',
    profession: 'Working',
    moveIn: DateTime.utc(2026, 11, 15),
    avatar: 'assets/avatars/avatar_01.webp',
  ),
  _Demand(
    id: 'isha',
    name: 'Isha Banerjee',
    city: 'Mumbai',
    localities: ['Andheri East', 'Powai'],
    budgetMin: 28000,
    budgetMax: 48000,
    roomType: '2bhk',
    furnishing: 'semi_furnished',
    amenities: ['wifi', 'ac', 'security'],
    about: 'Moving from Kolkata for a bank role in Andheri. Family of three.',
    profession: 'Working',
    moveIn: DateTime.utc(2026, 12, 10),
    avatar: 'assets/avatars/avatar_03.webp',
  ),
  _Demand(
    id: 'rohan',
    name: 'Rohan Kulkarni',
    city: 'Pune',
    localities: ['Kharadi', 'Viman Nagar'],
    budgetMin: 12000,
    budgetMax: 20000,
    roomType: 'shared',
    furnishing: 'furnished',
    amenities: ['wifi'],
    about: 'Intern near Kharadi. Happy to share a room.',
    profession: 'Student',
    moveIn: DateTime.utc(2026, 11, 6),
    avatar: 'assets/avatars/avatar_04.webp',
  ),
  _Demand(
    id: 'diya',
    name: 'Diya Kapoor',
    city: 'Delhi NCR',
    localities: ['Gurgaon', 'Sohna Road'],
    budgetMin: 35000,
    budgetMax: 55000,
    roomType: '3bhk',
    furnishing: 'furnished',
    amenities: ['wifi', 'ac', 'gym', 'security'],
    about: 'Moving with her parents for a year. A lift matters.',
    profession: 'Working',
    moveIn: DateTime.utc(2026, 12, 10),
    avatar: 'assets/avatars/avatar_05.webp',
  ),
  _Demand(
    id: 'farhan',
    name: 'Farhan Qureshi',
    city: 'Hyderabad',
    localities: ['Madhapur', 'Gachibowli'],
    budgetMin: 18000,
    budgetMax: 30000,
    roomType: '2bhk',
    furnishing: 'semi_furnished',
    amenities: ['wifi', 'power_backup', 'gym'],
    about: 'Consultant. Wants a gated society and covered parking.',
    profession: 'Working',
    moveIn: DateTime.utc(2027, 1, 5),
    avatar: 'assets/avatars/avatar_06.webp',
  ),
  _Demand(
    id: 'kavya',
    name: 'Kavya Iyer',
    city: 'Bengaluru',
    localities: ['Jayanagar'],
    budgetMin: 8000,
    budgetMax: 14000,
    roomType: 'shared',
    furnishing: 'unfurnished',
    amenities: ['wifi'],
    about: 'Postgraduate student. Budget is tight and the room can be shared.',
    profession: 'Student',
    moveIn: DateTime.utc(2026, 11, 2),
    avatar: 'assets/avatars/avatar_02.webp',
  ),
  _Demand(
    id: 'neel',
    name: 'Neel Shah',
    city: 'Ahmedabad',
    localities: ['Satellite', 'Bodakdev'],
    budgetMin: 14000,
    budgetMax: 26000,
    roomType: '2bhk',
    furnishing: 'semi_furnished',
    amenities: ['wifi', 'security'],
    about: 'Family of two. Prefers a residential pocket, not a main road.',
    profession: 'Working',
    moveIn: DateTime.utc(2026, 12, 20),
    avatar: 'assets/avatars/avatar_01.webp',
  ),
];

Future<List<SwipeMatchCardData>> propertyCards(FlowPrefs prefs) {
  return rankListings(
    listings: DemoCatalog.listings,
    prefs: prefs,
    score: (preference, listing) async {
      return scoreCompatibility(preference: preference, listing: listing);
    },
  );
}

List<SwipeMatchCardData> demandCards({
  required FlowPrefs prefs,
  required ListingDraft draft,
  required bool broker,
}) {
  final offer = broker ? _brokerOffer(prefs) : _draftOffer(draft);
  final cards = <SwipeMatchCardData>[
    for (final seeker in _demands) _demandCard(seeker, offer),
  ];
  return _pickVariety(cards);
}

List<SwipeMatchCardData> peopleCards({
  required FlowPrefs prefs,
  RoomieBrief? saved,
}) {
  final viewer = saved ?? _viewerBrief(prefs);
  final cards = <SwipeMatchCardData>[
    for (var i = 0; i < roomiePeople.length; i++)
      _personCard(roomiePeople[i], viewer, i),
  ];
  return _pickVariety(cards);
}

SwipeMatchCardData _demandCard(_Demand seeker, _Offer offer) {
  final base = requirementListingMatch(
    listingCity: offer.city,
    listingLocality: offer.locality,
    rentInr: offer.rent,
    propertyType: offer.propertyType,
    furnishing: offer.furnishing,
    listingAmenities: offer.amenities,
    availableFrom: DateTime.utc(2026, 11),
    requirementCity: seeker.city,
    requirementLocalities: seeker.localities,
    budgetMinInr: seeker.budgetMin,
    budgetMaxInr: seeker.budgetMax,
    roomType: seeker.roomType,
    propertyTypes: const [],
    requirementFurnishing: seeker.furnishing,
    requirementAmenities: seeker.amenities,
    moveInDate: seeker.moveIn,
  );
  final cityFits = _same(seeker.city, offer.city);
  final budgetFits = _budgetNear(offer.rent, seeker.budgetMin, seeker.budgetMax);
  final typeFits = _typeFitsRoom(offer.propertyType, seeker.roomType);
  final important = !cityFits || !budgetFits || !typeFits;
  final places = seeker.localities.join(', ');
  final amenityLabels = [
    for (final item in seeker.amenities) requirementAmenityLabel(item),
  ].join(', ');
  final score = combineScore(
    base: base,
    reasons: [
      cityFits
          ? 'City matches ${offer.city}.'
          : 'City does not match ${offer.city}.',
      seeker.localities.any((item) => _same(item, offer.locality))
          ? 'Locality matches ${offer.locality}.'
          : 'Locality is outside ${seeker.name.split(' ').first}\'s list.',
      budgetFits
          ? 'Your rent fits their budget.'
          : 'Your rent misses their budget.',
      typeFits ? 'Home type fits what they asked.' : 'Home type does not fit.',
      'Budget ${formatInr(seeker.budgetMin)} – ${formatInr(seeker.budgetMax)}.',
      'Amenities they want: $amenityLabels.',
      seeker.about,
    ],
    importantMismatch: important,
    signals: signalsFor(
      seeker.id,
      identityVerified: _stableEven(seeker.id),
      photoVerified: true,
      quality: 6,
      ageDays: _ageDays(seeker.moveIn),
    ),
  );
  return SwipeMatchCardData(
    id: seeker.id,
    title: seeker.name,
    subtitle: '$places, ${seeker.city}',
    meta:
        '${formatInr(seeker.budgetMin)} – ${formatInr(seeker.budgetMax)} · ${seeker.profession} · ${requirementRoomTypeLabel(seeker.roomType)}',
    photoAsset: seeker.avatar,
    percent: score.percent,
    importantMismatch: score.importantMismatch,
    reasons: score.reasons,
    badges: _badges(
      identity: _stableEven(seeker.id),
      ownership: false,
      photo: true,
    ),
  );
}

SwipeMatchCardData _personCard(RoomiePerson person, RoomieBrief viewer, int index) {
  final fit = roomieFit(viewer, person.brief, otherGender: person.gender);
  final cityFits = _same(person.brief.city, viewer.city);
  final important = !cityFits || fit.overlap == null;
  final avatar = 'assets/avatars/avatar_0${(index % 6) + 1}.webp';
  final score = combineScore(
    base: fit.percent,
    reasons: [
      fit.budgetDetail,
      fit.localityDetail,
      fit.moveInDetail,
      fit.lifestyleDetail,
      if (fit.matchLine.isNotEmpty) fit.matchLine,
    ],
    importantMismatch: important,
    signals: signalsFor(
      person.id,
      identityVerified: person.likesYou || _stableEven(person.id),
      photoVerified: true,
      quality: person.brief.lifestyleNote.trim().isEmpty ? 5 : 8,
      ageDays: 12,
    ),
  );
  final places = person.brief.localities.take(2).join(', ');
  return SwipeMatchCardData(
    id: person.id,
    title: '${person.name}, ${person.age}',
    subtitle: '$places, ${person.brief.city}',
    meta:
        '${person.occupation} · ${formatInr(person.brief.budgetLow)} – ${formatInr(person.brief.budgetHigh)}',
    photoAsset: avatar,
    percent: score.percent,
    importantMismatch: score.importantMismatch,
    reasons: score.reasons,
    badges: _badges(
      identity: person.likesYou || _stableEven(person.id),
      ownership: false,
      photo: true,
    ),
  );
}

RoomieBrief _viewerBrief(FlowPrefs prefs) {
  return RoomieBrief(
    budgetMinInr: prefs.budgetLow,
    budgetMaxInr: prefs.budgetHigh,
    city: prefs.city,
    localities: prefs.localities,
    moveIn: DateTime.utc(2026, 12),
    occupation: 'Working professional',
    food: 'vegetarian',
    smoking: 'no',
    drinking: 'no',
    guests: 'rarely',
    cooking: 'cook_myself',
    genderPreference: 'any',
    lifestyleNote: prefs.note,
  );
}

_Offer _draftOffer(ListingDraft draft) {
  final rent = int.tryParse(draft.rentText.replaceAll(RegExp('[^0-9]'), ''));
  if (draft.city.trim().isEmpty || rent == null || rent <= 0) {
    return _sampleOffer;
  }
  final amenities = draft.amenities.isEmpty
      ? _sampleOffer.amenities
      : _amenityKeys(draft.amenities);
  return _Offer(
    city: draft.city.trim(),
    locality: draft.locality.trim().isEmpty
        ? _sampleOffer.locality
        : draft.locality.trim(),
    rent: rent,
    furnishing: draft.furnishing,
    amenities: amenities,
    propertyType: draft.propertyType,
  );
}

_Offer _brokerOffer(FlowPrefs prefs) {
  return _Offer(
    city: prefs.brokerCity,
    locality: prefs.brokerLocality,
    rent: prefs.brokerPrice,
    furnishing: 'semi_furnished',
    amenities: prefs.brokerAmenities,
    propertyType: 'apartment',
  );
}

List<SwipeMatchCardData> _pickVariety(List<SwipeMatchCardData> all) {
  final sorted = [...all]..sort((a, b) => b.percent.compareTo(a.percent));
  SwipeMatchCardData? green;
  SwipeMatchCardData? yellow;
  SwipeMatchCardData? red;
  for (final card in sorted) {
    final strength = cappedStrength(
      card.percent,
      importantMismatch: card.importantMismatch,
    );
    if (strength == MatchStrength.strong && green == null) {
      green = card;
    } else if (strength == MatchStrength.partial && yellow == null) {
      yellow = card;
    } else if (strength == MatchStrength.low && red == null) {
      red = card;
    }
  }
  final picked = <SwipeMatchCardData>[];
  void add(SwipeMatchCardData? card) {
    if (card == null || picked.any((item) => item.id == card.id)) {
      return;
    }
    picked.add(card);
  }

  add(green);
  add(yellow);
  add(red);
  for (final card in sorted) {
    if (picked.length >= 8) {
      break;
    }
    add(card);
  }
  return picked;
}

List<FlowBadge> _badges({
  required bool identity,
  required bool ownership,
  required bool photo,
}) {
  return [
    if (identity) FlowBadge.identity,
    if (ownership) FlowBadge.ownership,
    if (photo) FlowBadge.photo,
  ];
}

List<String> _amenityKeys(List<String> raw) {
  final keys = <String>{};
  for (final item in raw) {
    final value = item.toLowerCase();
    if (value.contains('wifi') || value.contains('wi-fi')) {
      keys.add('wifi');
    }
    if (value.contains('ac') || value.contains('air')) {
      keys.add('ac');
    }
    if (value.contains('wash')) {
      keys.add('washing_machine');
    }
    if (value.contains('power')) {
      keys.add('power_backup');
    }
    if (value.contains('gym')) {
      keys.add('gym');
    }
    if (value.contains('security') || value.contains('cctv')) {
      keys.add('security');
    }
  }
  return keys.toList();
}

bool _typeFitsRoom(String propertyType, String roomType) {
  if (roomType == 'shared') {
    return propertyType == 'shared_room' ||
        propertyType == 'pg' ||
        propertyType == 'apartment';
  }
  return propertyType != 'pg';
}

bool _budgetNear(int rent, int low, int high) {
  return rent >= (low * 0.8).round() && rent <= (high * 1.2).round();
}

int _ageDays(DateTime moveIn) {
  final raw = flowScoreToday.difference(moveIn).inDays.abs();
  if (raw > 80) {
    return 80;
  }
  return raw;
}

bool _stableEven(String id) {
  final sum = id.codeUnits.fold<int>(0, (total, unit) => total + unit);
  return sum.isEven;
}

bool _same(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();
