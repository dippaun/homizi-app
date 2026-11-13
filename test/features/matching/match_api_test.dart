import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/matching/match_catalog.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';
import 'package:homizi/features/roommates/domain/roommate_compatibility.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';

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
    expect(over.percent, overDirect.score);
    expect(over.missing, contains('Exceeds budget'));
    expect(over.topReasons.length, lessThanOrEqualTo(5));
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
    expect(result.percent, direct.score);
    expect(result.percent, 100);
    expect(result.topReasons, contains('Working professional'));
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
    expect(
      rejected.percent,
      scoreHostLead(priorities: fromHome, lead: ananya).score,
    );
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
    final directLow = roommateCompatibility(demoViewerTraits, rohan.traits);

    expect(high.percent, directHigh.score);
    expect(high.percent, 95);
    expect(high.topReasons, contains('You both look in Bengaluru.'));
    expect(high.topReasons.length, lessThanOrEqualTo(5));
    expect(low.percent, directLow.score);
    expect(low.percent, 40);
    expect(low.missing, contains('Different cities.'));
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
