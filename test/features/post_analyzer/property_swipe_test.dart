import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_catalog.dart';
import 'package:homizi/features/post_analyzer/property_card_data.dart';
import 'package:homizi/features/post_analyzer/property_match_adapter.dart';
import 'package:homizi/features/post_analyzer/property_swipe_page.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/shared/widgets/homizi_property_card.dart';

class _SignedInTenant extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'meera.nair@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  test('saved nearby is parsed and a missing distance is dropped', () {
    expect(parseListingNearby('metro', 'Metro'), isNull);
    expect(parseListingNearby('metro', 'Metro|0|5'), isNull);
    final place = parseListingNearby('metro', 'Bandra West Metro|1.2|8');
    expect(place?.km, 1.2);
    expect(place?.name, 'Bandra West Metro');

    final listing = listingFromPropertyRow(
      {
        'id': 'p1',
        'host_user_id': 'h1',
        'title': 'Room',
        'locality': 'Bandra West',
        'city': 'Mumbai',
        'rent_inr': 25000,
        'furnishing': 'furnished',
        'property_type': 'private_room',
      },
      hostName: 'Rohan S.',
      features: [
        {'feature_key': 'near:metro', 'value': 'Metro|1.2|6'},
        {'feature_key': 'near:gym', 'value': 'Gym'},
      ],
    );
    expect(listing.nearbyPlaces, hasLength(1));
    expect(listing.nearbyPlaces.single.kind, 'metro');
  });

  test('the match percent comes from the existing scorer', () {
    final home = demoHomeById('lst_match_bandra');
    expect(home, isNotNull);
    final score = scoreSwipeProperty(
      listing: home!,
      priorities: const TenantPriorities(),
      commute: const CommuteContext(
        office: powaiOffice,
        mode: TransportMode.car,
        maxMinutes: 30,
      ),
    );
    expect(score.percent, isNotNull);
    expect(score.percent, inInclusiveRange(0, 100));
    expect(score.topReasons, isNotEmpty);
    expect(score.topReasons.length, lessThanOrEqualTo(5));
    for (final reason in score.topReasons) {
      expect(reason.toLowerCase().contains('km'), isFalse);
      expect(reason.toLowerCase().contains('commute'), isFalse);
    }
    final data = propertyCardData(listing: home, score: score, saved: false);
    expect(data.matchPercent, score.percent);
    expect(data.nearby.map((place) => place.distanceLabel).toList(), [
      '1.2 km',
      '1.5 km',
      '0.4 km',
      '1.1 km',
      '0.7 km',
    ]);
    expect(data.commuteLabel, isNull);
    expect(data.photos.first.caption, 'Room (Main Photo)');
    expect(
      officeCommuteLine(
        officeSaved: true,
        mapsEnabled: false,
        providerLine: '24 min',
      ),
      isNull,
    );
    expect(
      officeCommuteLine(
        officeSaved: false,
        mapsEnabled: true,
        providerLine: '24 min',
      ),
      isNull,
    );
    expect(
      officeCommuteLine(
        officeSaved: true,
        mapsEnabled: true,
        providerLine: '24 min by the maps provider',
      ),
      '24 min by the maps provider',
    );
    expect(
      officeWasSaved(officeIds: ['powai'], activeOfficeId: 'powai'),
      isFalse,
    );
  });

  test('a home with no saved places contributes no nearby row', () {
    const listing = Listing(
      id: 'plain',
      hostUserId: 'h',
      title: '1BHK in Andheri East',
      city: 'Mumbai',
      locality: 'Andheri East',
      rentInr: 28000,
      depositInr: 56000,
      furnishing: 'semi_furnished',
      propertyType: 'apartment',
      hostDisplayName: 'Neha Sharma',
      amenities: ['WiFi'],
      summary: 'A semi-furnished home.',
    );
    final data = propertyCardData(
      listing: listing,
      score: const PropertyMatchScore(
        percent: null,
        topReasons: [],
        missing: [],
        importantMismatch: false,
        strong: false,
      ),
      saved: false,
    );
    expect(data.matchPercent, isNull);
    expect(data.nearby, isEmpty);
    expect(data.commuteLabel, isNull);
  });

  testWidgets('the swipe page shows the card, skip, and interest', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 1688);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The deck now uses the shared listing scorer; this seeker wants
          // the Bandra West room so it leads the deck.
          sessionProvider.overrideWith(_SignedInTenant.new),
          activeRequirementProvider.overrideWithValue(
            const DetailedRequirement(
              city: 'Mumbai',
              localities: ['Bandra West'],
              propertyTypes: ['private_room'],
              budgetMinInr: 20000,
              budgetMaxInr: 28000,
            ),
          ),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const PropertySwipePage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('swipe-card')), findsOneWidget);
    expect(find.text('Private Room in 2BHK'), findsOneWidget);
    await tester.drag(
      find.descendant(
        of: find.byKey(const Key('swipe-card')),
        matching: find.byType(ListView),
      ),
      const Offset(0, -700),
    );
    await tester.pump();
    expect(find.text('Nearby Places'), findsOneWidget);
    expect(find.text('1.2 km'), findsOneWidget);
    expect(find.textContaining('% Match'), findsWidgets);
    expect(find.text('92% Match'), findsNothing);
    expect(find.textContaining('About'), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('match-skip')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Private Room in 2BHK'), findsNothing);

    await tester.drag(
      find.descendant(
        of: find.byKey(const Key('swipe-card')),
        matching: find.byType(ListView),
      ),
      const Offset(0, -900),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('match-interested')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('property-interest-sent')), findsOneWidget);
    expect(find.text('Interest sent'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('property-interest-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('property-swipe-page')), findsOneWidget);
  });

  testWidgets('compact card keeps the same title, rent, and match badge', (
    tester,
  ) async {
    const data = HomiziPropertyCardData(
      id: 'compact',
      title: 'Private Room in 2BHK',
      place: 'Bandra West, Mumbai',
      rentLabel: '₹25,000 / month',
      matchPercent: 88,
      verifiedListing: true,
      photos: [HomiziPropertyPhoto(ref: '', caption: 'Room (Main Photo)')],
      details: [
        HomiziPropertyDetail(
          icon: HomiziDetailIcon.room,
          label: 'Private Room',
        ),
        HomiziPropertyDetail(icon: HomiziDetailIcon.bhk, label: '2BHK'),
      ],
      amenities: ['Furnished'],
      topReasons: ['Within your budget (₹25,000)'],
      hostName: 'Rohan S.',
      hostVerified: true,
      hostRole: 'Owner',
      nearby: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: const Scaffold(
          body: HomiziPropertyCard(
            data: data,
            variant: HomiziPropertyCardVariant.compact,
          ),
        ),
      ),
    );
    expect(find.text('Private Room in 2BHK'), findsOneWidget);
    expect(find.text('₹25,000 / month'), findsOneWidget);
    expect(find.text('88% Match'), findsOneWidget);
    expect(find.text('Verified Listing'), findsOneWidget);
    expect(find.text("I'm Interested"), findsNothing);
    expect(find.text('Nearby Places'), findsNothing);
  });
}
