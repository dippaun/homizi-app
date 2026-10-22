import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';

const powaiOffice = OfficePlace(
  id: 'powai',
  label: 'My Office · Powai, Mumbai',
  area: 'Powai',
  latitude: 19.1176,
  longitude: 72.905,
);

const bkcOffice = OfficePlace(
  id: 'bkc',
  label: 'BKC, Mumbai',
  area: 'BKC',
  latitude: 19.066,
  longitude: 72.869,
);

const andheriOffice = OfficePlace(
  id: 'andheri-east',
  label: 'Andheri East, Mumbai',
  area: 'Andheri East',
  latitude: 19.1136,
  longitude: 72.8697,
);

const presetOffices = <OfficePlace>[powaiOffice, bkcOffice, andheriOffice];

const demoViewerRoomie = RoomieProfile(
  budgetMinInr: 18000,
  budgetMaxInr: 30000,
  city: 'Mumbai',
  localities: ['Bandra West', 'Khar'],
  smoking: 'no',
  drinking: 'no',
  food: 'veg',
  cleanliness: 4,
  sleep: 'flexible',
  guests: 'rarely',
  cooking: 'sometimes',
);

const _bed = 'assets/photos/bed_01.webp';
const _kitchen = 'assets/photos/kitchen_01.webp';
const _bath = 'assets/photos/bath_01.webp';
const _living = 'assets/photos/living_01.webp';
const _balcony = 'assets/photos/balcony_01.webp';
const _exterior = 'assets/photos/exterior_01.webp';
const _bedB = 'assets/photos/bed_02.webp';
const _livingB = 'assets/photos/living_02.webp';
const _kitchenB = 'assets/photos/kitchen_02.webp';

const demoMatchHomes = <Listing>[
  Listing(
    id: 'lst_match_bandra',
    hostUserId: 'demo-host-rohan-s',
    title: 'Private Room in 2BHK',
    city: 'Mumbai',
    locality: 'Bandra West',
    rentInr: 25000,
    depositInr: 50000,
    furnishing: 'furnished',
    propertyType: 'private_room',
    hostDisplayName: 'Rohan S.',
    hostOccupation: 'Product designer',
    hostKind: 'Owner',
    hostVerified: true,
    listingVerified: true,
    demoReciprocal: true,
    amenities: ['AC', 'WiFi', 'Lift'],
    restrictions: ['No smoking'],
    suitability: ['Working professionals'],
    summary:
        'A private room in a furnished 2 BHK at Bandra West. The exact address stays off this card.',
    photoAssets: [_bed, _kitchen, _bath, _living, _balcony, _exterior],
    areaSqft: 800,
    floorNo: 5,
    totalFloors: 12,
    preferredTenants: ['bachelors', 'female'],
    availableFromIso: '2026-12-20',
    publishedAtIso: '2026-10-18T09:00:00Z',
    replyWithinHours: 2,
    approxLatitude: 19.0596,
    approxLongitude: 72.8295,
  ),
  Listing(
    id: 'lst_match_powai',
    hostUserId: 'demo-host-meera',
    title: 'Furnished Room in Powai',
    city: 'Mumbai',
    locality: 'Powai',
    rentInr: 24000,
    depositInr: 48000,
    furnishing: 'furnished',
    propertyType: 'private_room',
    hostDisplayName: 'Meera K.',
    hostOccupation: 'Architect',
    hostKind: 'Owner',
    hostVerified: true,
    listingVerified: true,
    amenities: ['AC', 'WiFi', 'Gym'],
    restrictions: ['No smoking'],
    suitability: ['Working professionals'],
    summary: 'A furnished room near Powai lake. Contact stays behind a match.',
    photoAssets: [_livingB, _bedB, _kitchenB, _bath],
    areaSqft: 720,
    floorNo: 3,
    preferredTenants: ['any'],
    availableFromIso: '2026-11-15',
    publishedAtIso: '2026-10-20T09:00:00Z',
    replyWithinHours: 3,
    approxLatitude: 19.117,
    approxLongitude: 72.905,
  ),
  Listing(
    id: 'lst_match_bandra_rent',
    hostUserId: 'demo-host-kabir',
    title: 'Large Room in Bandra West',
    city: 'Mumbai',
    locality: 'Bandra West',
    rentInr: 48000,
    depositInr: 96000,
    furnishing: 'furnished',
    propertyType: 'private_room',
    hostDisplayName: 'Kabir N.',
    hostOccupation: 'Lawyer',
    hostKind: 'Owner',
    hostVerified: true,
    amenities: ['AC', 'WiFi'],
    restrictions: ['No smoking'],
    suitability: ['Working professionals'],
    summary:
        'A larger furnished room in Bandra West, above a typical shared budget.',
    photoAssets: [_bed, _living, _kitchen],
    areaSqft: 900,
    floorNo: 8,
    preferredTenants: ['any'],
    availableFromIso: '2026-11-01',
    publishedAtIso: '2026-09-01T09:00:00Z',
    replyWithinHours: 6,
    approxLatitude: 19.06,
    approxLongitude: 72.83,
  ),
  Listing(
    id: 'lst_match_andheri',
    hostUserId: 'demo-host-neha',
    title: '1BHK in Andheri East',
    city: 'Mumbai',
    locality: 'Andheri East',
    rentInr: 28000,
    depositInr: 56000,
    furnishing: 'semi_furnished',
    propertyType: 'apartment',
    bedrooms: 1,
    hostDisplayName: 'Neha Sharma',
    hostOccupation: 'Analyst',
    hostKind: 'Owner',
    hostVerified: true,
    listingVerified: true,
    amenities: ['WiFi', 'Lift'],
    restrictions: ['No smoking'],
    suitability: ['Working professionals'],
    summary:
        'A semi-furnished 1 BHK in Andheri East. Move-in is later in the year.',
    photoAssets: [_livingB, _bedB, _kitchenB],
    areaSqft: 540,
    floorNo: 2,
    preferredTenants: ['bachelors'],
    availableFromIso: '2027-03-01',
    publishedAtIso: '2026-08-12T09:00:00Z',
    replyWithinHours: 12,
    approxLatitude: 19.1136,
    approxLongitude: 72.8697,
    nonVegAllowed: true,
  ),
  Listing(
    id: 'lst_match_dadar',
    hostUserId: 'demo-host-imran',
    title: 'Shared Room in Dadar',
    city: 'Mumbai',
    locality: 'Dadar',
    rentInr: 42000,
    depositInr: 42000,
    furnishing: 'unfurnished',
    propertyType: 'shared_room',
    bedrooms: 1,
    occupancyMax: 3,
    hostDisplayName: 'Imran Q.',
    hostOccupation: 'Student',
    hostKind: 'Flatmate',
    amenities: ['Fan'],
    restrictions: ['Smoking allowed', 'Alcohol allowed'],
    summary:
        'A shared room in Dadar. Rent is above the demo budget and move-in is later.',
    photoAssets: [_bedB, _living],
    areaSqft: 280,
    preferredTenants: ['bachelors'],
    availableFromIso: '2027-06-01',
    publishedAtIso: '2026-07-01T09:00:00Z',
    approxLatitude: 19.0178,
    approxLongitude: 72.8478,
    petsAllowed: true,
    nonVegAllowed: true,
  ),
];

const demoTenantLeads = <TenantLead>[
  TenantLead(
    id: 'lead_ananya',
    name: 'Ananya Iyer',
    city: 'Mumbai',
    locality: 'Bandra West',
    budgetMinInr: 20000,
    budgetMaxInr: 28000,
    workingProfessional: true,
    nonDrinker: true,
    nonSmoker: true,
    cleanliness: 5,
    gender: 'woman',
    longStay: true,
    furnishing: 'furnished',
    hasPets: false,
    verified: true,
    likesYou: true,
    about: 'Product designer looking for a quiet furnished room for a year.',
    roomie: RoomieProfile(
      budgetMinInr: 20000,
      budgetMaxInr: 28000,
      city: 'Mumbai',
      localities: ['Bandra West'],
      smoking: 'no',
      drinking: 'no',
      food: 'veg',
      cleanliness: 4,
      sleep: 'early',
      guests: 'rarely',
      cooking: 'sometimes',
    ),
  ),
  TenantLead(
    id: 'lead_neha',
    name: 'Neha Kulkarni',
    city: 'Mumbai',
    locality: 'Andheri East',
    budgetMinInr: 18000,
    budgetMaxInr: 26000,
    workingProfessional: true,
    nonDrinker: false,
    nonSmoker: false,
    cleanliness: 3,
    gender: 'woman',
    longStay: false,
    furnishing: 'semi_furnished',
    hasPets: true,
    verified: true,
    likesYou: false,
    about: 'Analyst open to a shorter stay. Has a small dog.',
    roomie: RoomieProfile(
      budgetMinInr: 18000,
      budgetMaxInr: 26000,
      city: 'Mumbai',
      localities: ['Andheri East'],
      smoking: 'yes',
      drinking: 'yes',
      food: 'both',
      cleanliness: 3,
      sleep: 'flexible',
      guests: 'occasionally',
      cooking: 'sometimes',
    ),
  ),
  TenantLead(
    id: 'lead_kabir',
    name: 'Kabir Seth',
    city: 'Mumbai',
    locality: 'Dadar',
    budgetMinInr: 8000,
    budgetMaxInr: 12000,
    workingProfessional: false,
    nonDrinker: false,
    nonSmoker: false,
    cleanliness: 1,
    gender: 'man',
    longStay: false,
    furnishing: 'unfurnished',
    hasPets: true,
    verified: false,
    likesYou: false,
    about: 'Student looking for a short shared stay in Dadar.',
    roomie: RoomieProfile(
      budgetMinInr: 8000,
      budgetMaxInr: 12000,
      city: 'Mumbai',
      localities: ['Dadar'],
      smoking: 'yes',
      drinking: 'yes',
      food: 'non_veg',
      cleanliness: 1,
      sleep: 'night',
      guests: 'frequently',
      cooking: 'rarely',
    ),
  ),
];

const nearbyByLocality = <String, List<String>>{
  'Bandra West': [
    '1.2 km Metro',
    '1.5 km Station',
    '0.4 km Supermarket',
    '1.1 km Hospital',
    '0.7 km Gym',
  ],
  'Powai': [
    '0.6 km Metro',
    '1.1 km Station',
    '0.3 km Supermarket',
    '1.4 km Hospital',
    '0.5 km Gym',
  ],
  'Andheri East': [
    '0.8 km Metro',
    '0.9 km Station',
    '0.5 km Supermarket',
    '1.6 km Hospital',
    '0.9 km Gym',
  ],
  'Dadar': [
    '0.4 km Station',
    '0.7 km Metro',
    '0.3 km Supermarket',
    '1.2 km Hospital',
    '1.0 km Gym',
  ],
};

Listing? demoHomeById(String id) {
  for (final home in demoMatchHomes) {
    if (home.id == id) {
      return home;
    }
  }
  return null;
}

TenantLead? demoLeadById(String id) {
  for (final lead in demoTenantLeads) {
    if (lead.id == id) {
      return lead;
    }
  }
  return null;
}

List<MatchCardModel> tenantMatchCards({
  required TenantPriorities priorities,
  required CommuteContext commute,
  LearnedSignals signals = LearnedSignals.empty,
}) {
  final cards = <MatchCardModel>[
    for (final home in demoMatchHomes)
      _homeCard(
        home,
        priorities: priorities,
        commute: commute,
        signals: signals,
      ),
  ];
  cards.sort((a, b) => compareBreakdowns(a.breakdown, b.breakdown));
  return cards;
}

List<MatchCardModel> hostMatchCards({
  required HostPriorities priorities,
  required CommuteContext commute,
  required RoomieProfile viewer,
  LearnedSignals signals = LearnedSignals.empty,
}) {
  final cards = <MatchCardModel>[
    for (final lead in demoTenantLeads)
      _leadCard(
        lead,
        priorities: priorities,
        commute: commute,
        viewer: viewer,
        signals: signals,
      ),
  ];
  cards.sort((a, b) => compareBreakdowns(a.breakdown, b.breakdown));
  return cards;
}

MatchCardModel? matchCardById({
  required String id,
  required MatchSide side,
  required TenantPriorities tenant,
  required HostPriorities host,
  required CommuteContext commute,
  required RoomieProfile viewer,
  LearnedSignals signals = LearnedSignals.empty,
}) {
  final cards = side == MatchSide.tenant
      ? tenantMatchCards(priorities: tenant, commute: commute, signals: signals)
      : hostMatchCards(
          priorities: host,
          commute: commute,
          viewer: viewer,
          signals: signals,
        );
  for (final card in cards) {
    if (card.id == id) {
      return card;
    }
  }
  return null;
}

MatchCardModel _homeCard(
  Listing home, {
  required TenantPriorities priorities,
  required CommuteContext commute,
  required LearnedSignals signals,
}) {
  final breakdown = scoreTenantListing(
    priorities: priorities,
    listing: home,
    commute: commute,
    signals: signals,
  );
  final minutes = commuteMinutesFor(
    locality: home.locality,
    latitude: home.approxLatitude,
    longitude: home.approxLongitude,
    commute: commute,
  );
  final floor = home.floorNo == null ? '' : ' · ${home.floorNo}th floor';
  final area = home.areaSqft == null ? '' : ' · ${home.areaSqft} sq ft';
  return MatchCardModel(
    id: home.id,
    title: home.title,
    place: '${home.locality}, ${home.city}',
    priceLabel: '${formatInr(home.rentInr)} / month',
    personName: home.hostDisplayName,
    personRole: home.hostKind,
    breakdown: breakdown,
    commuteMinutes: minutes,
    reciprocal: home.demoReciprocal,
    photoAssets: home.photoAssets,
    nearby: nearbyByLocality[home.locality] ?? const [],
    keyDetails: '${home.bhkLabel}$area$floor',
    replyLabel: home.replyWithinHours == null
        ? 'New host'
        : 'Responds within ${home.replyWithinHours} hours',
    chips: [
      home.furnishingLabel,
      if (home.amenities.any((item) => item.toLowerCase() == 'ac')) 'AC',
      if (home.amenities.any((item) => item.toLowerCase() == 'wifi')) 'WiFi',
      if (home.restrictions.any(
        (item) => item.toLowerCase().contains('no smoking'),
      ))
        'No Smoking',
      if (home.preferredTenants.contains('bachelors')) 'Bachelor Friendly',
    ],
    withinBudget: _rentInside(home.rentInr, priorities),
    about: home.summary,
  );
}

MatchCardModel _leadCard(
  TenantLead lead, {
  required HostPriorities priorities,
  required CommuteContext commute,
  required RoomieProfile viewer,
  required LearnedSignals signals,
}) {
  final breakdown = scoreHostLead(
    priorities: priorities,
    lead: lead,
    signals: signals,
  );
  final roomie = roomieCompatibility(viewer, lead.roomie);
  final minutes = commuteMinutesFor(
    locality: lead.locality,
    latitude: null,
    longitude: null,
    commute: commute,
  );
  return MatchCardModel(
    id: lead.id,
    title: lead.name,
    place: '${lead.locality}, ${lead.city}',
    priceLabel:
        '${formatInr(lead.budgetMinInr)}–${formatInr(lead.budgetMaxInr)}',
    personName: lead.name,
    personRole: lead.workingProfessional ? 'Working professional' : 'Student',
    breakdown: breakdown,
    roomiePercent: roomie.percent,
    commuteMinutes: minutes,
    reciprocal: lead.likesYou,
    photoAssets: const [],
    nearby: nearbyByLocality[lead.locality] ?? const [],
    keyDetails: lead.about,
    replyLabel: lead.verified ? 'Verified profile' : 'Verification pending',
    chips: [
      if (lead.nonSmoker) 'Non-smoker',
      if (lead.nonDrinker) 'Non-drinker',
      if (lead.longStay) 'Long-term',
      if (lead.hasPets) 'Has pets',
    ],
    withinBudget: _rangesOverlap(
      lead.budgetMinInr,
      lead.budgetMaxInr,
      viewer.budgetMinInr,
      viewer.budgetMaxInr,
    ),
    about: lead.about,
  );
}

bool _rentInside(int rent, TenantPriorities priorities) {
  final low = priorities.budgetMinInr <= priorities.budgetMaxInr
      ? priorities.budgetMinInr
      : priorities.budgetMaxInr;
  final high = priorities.budgetMinInr <= priorities.budgetMaxInr
      ? priorities.budgetMaxInr
      : priorities.budgetMinInr;
  return rent >= low && rent <= high;
}

bool _rangesOverlap(int aMin, int aMax, int bMin, int bMax) {
  final left = aMin <= aMax ? aMin : aMax;
  final right = aMin <= aMax ? aMax : aMin;
  final otherLeft = bMin <= bMax ? bMin : bMax;
  final otherRight = bMin <= bMax ? bMax : bMin;
  return left <= otherRight && otherLeft <= right;
}
