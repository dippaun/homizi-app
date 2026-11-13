import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/matching/match_catalog.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';
import 'package:homizi/features/roommates/domain/roommate_compatibility.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

Listing _tweak(Listing source, {int? rentInr, List<String>? preferredTenants}) {
  return Listing(
    id: source.id,
    hostUserId: source.hostUserId,
    title: source.title,
    city: source.city,
    locality: source.locality,
    rentInr: rentInr ?? source.rentInr,
    depositInr: source.depositInr,
    furnishing: source.furnishing,
    propertyType: source.propertyType,
    hostDisplayName: source.hostDisplayName,
    amenities: source.amenities,
    summary: source.summary,
    bedrooms: source.bedrooms,
    occupancyMax: source.occupancyMax,
    availableFromIso: source.availableFromIso,
    restrictions: source.restrictions,
    suitability: source.suitability,
    preferredTenants: preferredTenants ?? source.preferredTenants,
    nonVegAllowed: source.nonVegAllowed,
    petsAllowed: source.petsAllowed,
    bathroom: source.bathroom,
  );
}

void main() {
  const commute = CommuteContext(
    office: powaiOffice,
    mode: TransportMode.car,
    maxMinutes: 30,
  );

  test('scoreProperty returns the existing tenant listing score', () {
    const seeker = TenantPriorities();
    final bandra = demoHomeById('lst_match_bandra')!;
    final dadar = demoHomeById('lst_match_dadar')!;
    final direct = scoreTenantListing(
      priorities: seeker,
      listing: bandra,
      commute: commute,
    );
    final result = scoreProperty(seeker, bandra, commute: commute);

    expect(result.percent, direct.score);
    expect(result.percent, inInclusiveRange(90, 95));
    expect(result.topReasons, direct.topReasons);
    expect(result.topReasons.length, lessThanOrEqualTo(5));
    expect(result.topReasons, contains('Within your budget'));
    expect(result.topReasons, contains('Preferred location (Bandra West)'));
    expect(result.missing, isEmpty);

    final over = scoreProperty(seeker, dadar, commute: commute);
    final overDirect = scoreTenantListing(
      priorities: seeker,
      listing: dadar,
      commute: commute,
    );
    expect(over.percent, lessThanOrEqualTo(overDirect.score));
    expect(over.percent, lessThanOrEqualTo(39));
    expect(over.missing, contains('Exceeds budget'));
    expect(over.topReasons.length, lessThanOrEqualTo(5));
  });

  test('a gender miss caps a strong home in the low band', () {
    const seeker = TenantPriorities(gender: 'women');
    final menOnly = _tweak(
      demoHomeById('lst_match_bandra')!,
      preferredTenants: const ['men'],
    );
    final raw = scoreTenantListing(
      priorities: seeker,
      listing: menOnly,
      commute: commute,
    );
    final result = scoreProperty(seeker, menOnly, commute: commute);
    expect(raw.score, greaterThan(39));
    expect(result.percent, lessThanOrEqualTo(39));
    expect(result.missing, contains('Gender preference does not match'));
    expect(result.topReasons.length, lessThanOrEqualTo(5));
  });

  test('priority order changes the percent when nothing is a hard miss', () {
    const seeker = TenantPriorities(
      budgetMinInr: 20000,
      budgetMaxInr: 28000,
      localities: ['Bandra West'],
    );
    final home = _tweak(demoHomeById('lst_match_bandra')!, rentInr: 32000);
    const budgetFirst = <TenantFactorId>[
      TenantFactorId.budget,
      TenantFactorId.location,
      TenantFactorId.occupancy,
      TenantFactorId.propertyType,
      TenantFactorId.gender,
      TenantFactorId.lifestyle,
      TenantFactorId.furnishing,
    ];
    const locationFirst = <TenantFactorId>[
      TenantFactorId.location,
      TenantFactorId.occupancy,
      TenantFactorId.propertyType,
      TenantFactorId.gender,
      TenantFactorId.lifestyle,
      TenantFactorId.furnishing,
      TenantFactorId.budget,
    ];
    final budgetRanked = scoreProperty(
      seeker,
      home,
      commute: commute,
      priorityOrder: budgetFirst,
    );
    final locationRanked = scoreProperty(
      seeker,
      home,
      commute: commute,
      priorityOrder: locationFirst,
    );
    expect(budgetRanked.missing, isNot(contains('Exceeds budget')));
    expect(locationRanked.percent, greaterThan(budgetRanked.percent));
  });

  test('a missing office is not turned into commute minutes', () {
    final seeker = const TenantPriorities().prioritizeCommute();
    final bandra = demoHomeById('lst_match_bandra')!;
    final result = scoreProperty(seeker, bandra);
    final text = [...result.topReasons, ...result.missing].join(' ');

    expect(text, isNot(contains('min')));
    expect(text, isNot(contains('hr')));
    expect(result.topReasons.length, lessThanOrEqualTo(5));
  });

  test('scoreSeeker reads the listing and uses the host scorer', () {
    final listing = demoHomeById('lst_match_bandra')!;
    final ananya = demoLeadById('lead_ananya')!;
    final priorities = hostPrioritiesFromListing(listing);
    final direct = scoreHostLead(priorities: priorities, lead: ananya);
    final result = scoreSeeker(listing, ananya);

    expect(priorities.gender, 'any');
    expect(priorities.furnishing, 'furnished');
    expect(priorities.petsAllowed, isFalse);
    expect(direct.score, 100);
    expect(result.percent, 100);
    expect(result.topReasons, contains('Rent is inside the seeker budget'));
    expect(result.topReasons.length, lessThanOrEqualTo(5));
    expect(result.missing, isEmpty);

    const menOnly = Listing(
      id: 'lst_pune_men',
      hostUserId: 'host-rahul',
      title: 'Room in a 2BHK',
      city: 'Pune',
      locality: 'Kothrud',
      rentInr: 14000,
      depositInr: 28000,
      furnishing: 'semi_furnished',
      propertyType: 'private_room',
      hostDisplayName: 'Rahul Deshmukh',
      amenities: ['WiFi'],
      summary: 'A room for men in Kothrud.',
      preferredTenants: ['men'],
      petsAllowed: true,
    );
    final fromHome = hostPrioritiesFromListing(menOnly);
    expect(fromHome.gender, 'men');
    expect(fromHome.petsAllowed, isTrue);
    final rejected = scoreSeeker(menOnly, ananya);
    expect(rejected.missing, contains('Gender preference does not match'));
    expect(rejected.missing, contains('Rent is outside the seeker budget'));
    expect(rejected.percent, lessThanOrEqualTo(31));
    expect(rejected.topReasons.length, lessThanOrEqualTo(5));
  });

  test('scoreRoommate returns the existing compatibility score', () {
    final mira = demoRoommateSeekers.firstWhere(
      (seeker) => seeker.name == 'Mira Shah',
    );
    final rohan = demoRoommateSeekers.firstWhere(
      (seeker) => seeker.name == 'Rohan Mehta',
    );
    final high = scoreRoommate(demoViewerTraits, mira.traits);
    final low = scoreRoommate(demoViewerTraits, rohan.traits);
    final directHigh = roommateCompatibility(demoViewerTraits, mira.traits);

    expect(directHigh.score, 95);
    expect(high.percent, inInclusiveRange(70, 100));
    expect(high.topReasons, isNotEmpty);
    expect(high.topReasons.length, lessThanOrEqualTo(5));
    expect(low.missing, contains('Different cities.'));
    expect(low.percent, lessThan(high.percent));
    expect(low.topReasons.length, lessThanOrEqualTo(5));
    expect(scoreRoommate(mira.traits, demoViewerTraits).percent, high.percent);
  });

  test('top reasons stay at five when many lines match', () {
    final perfect = scoreRoommate(demoViewerTraits, demoViewerTraits);
    expect(perfect.percent, 100);
    expect(perfect.topReasons, hasLength(5));
    expect(perfect.missing, isEmpty);

    const quiet = RoommateTraits(city: 'Hyderabad');
    final thin = scoreRoommate(quiet, const RoommateTraits(city: 'Hyderabad'));
    expect(thin.topReasons.length, lessThanOrEqualTo(5));
  });
}
