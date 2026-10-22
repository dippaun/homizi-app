import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/widgets/match_score.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_catalog.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';

void main() {
  const commute = CommuteContext(
    office: powaiOffice,
    mode: TransportMode.car,
    maxMinutes: 30,
  );

  Listing home({
    required String id,
    required String locality,
    required int rent,
    bool verified = false,
    bool nonVeg = false,
    int photos = 0,
    int? replyHours,
    String? published,
    String? available,
  }) {
    return Listing(
      id: id,
      hostUserId: 'host',
      title: 'Room',
      city: 'Mumbai',
      locality: locality,
      rentInr: rent,
      depositInr: rent,
      furnishing: 'furnished',
      propertyType: 'private_room',
      hostDisplayName: 'Host',
      amenities: const [],
      summary: '',
      restrictions: const ['No smoking'],
      suitability: const ['Working professionals'],
      availableFromIso: available,
      hostVerified: verified,
      listingVerified: verified,
      photoAssets: [
        for (var i = 0; i < photos; i++) 'assets/photos/bed_01.webp',
      ],
      publishedAtIso: published,
      replyWithinHours: replyHours,
      approxLatitude: 19.06,
      approxLongitude: 72.83,
      nonVegAllowed: nonVeg,
    );
  }

  test('colour bands are 70, 40, and red below that', () {
    expect(matchStrength(100), MatchStrength.strong);
    expect(matchStrength(70), MatchStrength.strong);
    expect(matchStrength(69), MatchStrength.partial);
    expect(matchStrength(40), MatchStrength.partial);
    expect(matchStrength(39), MatchStrength.low);
    expect(matchStrength(0), MatchStrength.low);
    expect(matchTone(70).background, const Color(0xFF146C36));
    expect(matchTone(69).background, const Color(0xFFFFF4D6));
    expect(matchTone(40).background, const Color(0xFFFFF4D6));
    expect(matchTone(39).background, const Color(0xFFFDECEC));
    expect(matchLineForScore(70), 'Matches your top 5 priorities');
    expect(matchLineForScore(40), 'Some preferences differ');
    expect(matchLineForScore(39), 'Major preferences not matched');
    expect(cappedStrength(92, importantMismatch: true), MatchStrength.low);
  });

  test('demo homes land in green, yellow, and red', () {
    const priorities = TenantPriorities();
    final bandra = scoreTenantListing(
      priorities: priorities,
      listing: demoHomeById('lst_match_bandra')!,
      commute: commute,
    );
    final andheri = scoreTenantListing(
      priorities: priorities,
      listing: demoHomeById('lst_match_andheri')!,
      commute: commute,
    );
    final dadar = scoreTenantListing(
      priorities: priorities,
      listing: demoHomeById('lst_match_dadar')!,
      commute: commute,
    );
    expect(bandra.score, inInclusiveRange(90, 95));
    expect(bandra.strength, MatchStrength.strong);
    expect(bandra.colourName, 'Green');
    expect(bandra.topReasons, contains('Within your budget'));
    expect(bandra.topReasons, contains('Preferred location (Bandra West)'));
    expect(bandra.topReasons, contains('Suitable for working professionals'));
    expect(andheri.strength, MatchStrength.partial);
    expect(andheri.colourName, 'Yellow');
    expect(andheri.differences, contains('Different locality'));
    expect(andheri.differences, contains('Furnishing preference differs'));
    expect(andheri.blockers, contains('Move-in date mismatch'));
    expect(dadar.strength, MatchStrength.low);
    expect(dadar.colourName, 'Red');
    expect(dadar.blockers, contains('Exceeds budget'));
    expect(dadar.headline, 'Not a good match because');

    final ranked = tenantMatchCards(priorities: priorities, commute: commute);
    expect(ranked.first.id, 'lst_match_bandra');
    final commuteOnly = filterMatchCards(
      ranked,
      MatchFeedChip.commute,
      maxMinutes: 30,
    );
    expect(commuteOnly.any((card) => card.id == 'lst_match_dadar'), isFalse);
    expect(commuteOnly.any((card) => card.id == 'lst_match_bandra'), isTrue);
  });

  test('a must-have miss caps the colour at red and stays visible', () {
    final priorities = const TenantPriorities().toggleMust(
      TenantFactorId.budget,
    );
    final scored = scoreTenantListing(
      priorities: priorities,
      listing: demoHomeById('lst_match_bandra_rent')!,
      commute: commute,
    );
    expect(scored.score, greaterThanOrEqualTo(matchStrongFloor));
    expect(scored.rawStrength, MatchStrength.strong);
    expect(scored.importantMismatch, isTrue);
    expect(scored.strength, MatchStrength.low);
    expect(scored.colourName, 'Red');
    expect(scored.blockers.first, 'Important mismatch');
    expect(scored.cardLine, contains('Important mismatch'));

    final ranked = tenantMatchCards(priorities: priorities, commute: commute);
    expect(ranked.last.id, 'lst_match_bandra_rent');
    final top = filterMatchCards(ranked, MatchFeedChip.top, maxMinutes: 30);
    expect(top.any((card) => card.id == 'lst_match_bandra_rent'), isFalse);
    expect(top.any((card) => card.id == 'lst_match_bandra'), isTrue);
  });

  test(
    'verification is a badge and boosters do not bury a better new home',
    () {
      final verified = scoreTenantListing(
        priorities: const TenantPriorities(),
        listing: home(
          id: 'verified',
          locality: 'Bandra West',
          rent: 25000,
          verified: true,
        ),
        commute: commute,
      );
      final plain = scoreTenantListing(
        priorities: const TenantPriorities(),
        listing: home(id: 'plain', locality: 'Bandra West', rent: 25000),
        commute: commute,
      );
      expect(plain.score, verified.score);
      expect(plain.boosterPoints, verified.boosterPoints);
      expect(verified.verified, isTrue);
      expect(plain.verified, isFalse);
      expect(verified.boosters.map((item) => item.label), [
        'Complete photos',
        'Recent listing',
        'High rating',
      ]);

      final newer = scoreTenantListing(
        priorities: const TenantPriorities(),
        listing: home(id: 'new', locality: 'Bandra West', rent: 25000),
        commute: commute,
      );
      final older = scoreTenantListing(
        priorities: const TenantPriorities(),
        listing: home(
          id: 'old',
          locality: 'Andheri East',
          rent: 25000,
          photos: 6,
          replyHours: 2,
          published: '2026-10-18T09:00:00Z',
        ),
        commute: commute,
      );
      expect(newer.score, greaterThan(older.score));
      expect(newer.boosterPoints, lessThan(older.boosterPoints));
      final ordered = [older, newer]..sort(compareBreakdowns);
      expect(ordered.first.score, newer.score);
    },
  );

  test('hosts and tenants are scored in opposite directions', () {
    final homes = tenantMatchCards(
      priorities: const TenantPriorities(),
      commute: commute,
    );
    final leads = hostMatchCards(
      priorities: const HostPriorities(),
      commute: commute,
      viewer: demoViewerRoomie,
    );
    expect(homes.first.id, 'lst_match_bandra');
    expect(leads.first.id, 'lead_ananya');
    expect(leads.last.id, 'lead_kabir');
    final ananya = demoLeadById('lead_ananya')!;
    final hostScore = scoreHostLead(
      priorities: const HostPriorities(),
      lead: ananya,
    );
    final roomie = roomieCompatibility(demoViewerRoomie, ananya.roomie);
    expect(hostScore.score, 100);
    expect(roomie.percent, lessThan(hostScore.score));
    expect(
      roomie.factors.map((factor) => factor.label),
      contains('Sleep schedule'),
    );
    expect(
      hostScore.factors.any((factor) => factor.label == 'Sleep schedule'),
      isFalse,
    );
    final changed = roomieCompatibility(
      demoViewerRoomie,
      ananya.roomie.copyWith(sleep: 'night'),
    );
    expect(changed.percent, lessThan(roomie.percent));
    expect(hostScore.score, 100);
  });

  test('commute is deterministic and can be ranked first', () {
    final minutes = commuteMinutesFor(
      locality: 'Bandra West',
      latitude: 19.0596,
      longitude: 72.8295,
      commute: commute,
    );
    expect(minutes, 28);
    expect(formatCommute(minutes), '28 min commute');
    expect(scaleCommuteMinutes(28, TransportMode.twoWheeler), 34);
    expect(scaleCommuteMinutes(28, TransportMode.publicTransport), 52);
    expect(scaleCommuteMinutes(28, TransportMode.walk), 130);
    expect(formatCommute(130), '2 hr 10 min commute');

    const plain = TenantPriorities();
    const tight = CommuteContext(
      office: powaiOffice,
      mode: TransportMode.car,
      maxMinutes: 15,
    );
    final ranked = plain.prioritizeCommute();
    expect(ranked.order.first, TenantFactorId.commute);
    final bandraPlain = scoreTenantListing(
      priorities: plain,
      listing: demoHomeById('lst_match_bandra')!,
      commute: tight,
    );
    final powaiPlain = scoreTenantListing(
      priorities: plain,
      listing: demoHomeById('lst_match_powai')!,
      commute: tight,
    );
    expect(bandraPlain.score, greaterThan(powaiPlain.score));
    final bandraRanked = scoreTenantListing(
      priorities: ranked,
      listing: demoHomeById('lst_match_bandra')!,
      commute: tight,
    );
    final powaiRanked = scoreTenantListing(
      priorities: ranked,
      listing: demoHomeById('lst_match_powai')!,
      commute: tight,
    );
    expect(powaiRanked.score, greaterThan(bandraRanked.score));
  });

  test('up to 10 priorities, and likes nudge then reset', () {
    final full = const TenantPriorities()
        .addFactor(TenantFactorId.commute)
        .addFactor(TenantFactorId.food);
    expect(full.order, hasLength(10));
    expect(full.addFactor(TenantFactorId.commute).order, hasLength(10));
    expect(full.removeFactor(TenantFactorId.budget).order, hasLength(10));
    expect(full.removeFactor(TenantFactorId.food).order, hasLength(9));

    final perfect = scoreTenantListing(
      priorities: full,
      listing: home(id: 'perfect', locality: 'Bandra West', rent: 25000),
      commute: commute,
    );
    expect(perfect.score, 100);

    final missedBudget = scoreTenantListing(
      priorities: full,
      listing: home(id: 'pricey', locality: 'Bandra West', rent: 90000),
      commute: commute,
    );
    final missedFood = scoreTenantListing(
      priorities: full,
      listing: home(
        id: 'kitchen',
        locality: 'Bandra West',
        rent: 25000,
        nonVeg: true,
      ),
      commute: commute,
    );
    expect(missedBudget.score, lessThan(missedFood.score));

    final moved = const TenantPriorities().reorder(0, 2);
    expect(moved.order[2], TenantFactorId.budget);
    expect(moved.order.first, TenantFactorId.occupancy);

    final base = scoreTenantListing(
      priorities: const TenantPriorities(),
      listing: demoHomeById('lst_match_bandra_rent')!,
      commute: commute,
    );
    final nudged = scoreTenantListing(
      priorities: const TenantPriorities(),
      listing: demoHomeById('lst_match_bandra_rent')!,
      commute: commute,
      signals: LearnedSignals.empty.bump('tenant:budget', 3),
    );
    expect(nudged.score, lessThan(base.score));
    expect(base.score - nudged.score, lessThanOrEqualTo(matchNudgeScoreCap));
    final learned = signalsAfterDecision(
      LearnedSignals.empty,
      base,
      liked: false,
    );
    expect(learned.weights, isNotEmpty);
    final cleared = scoreTenantListing(
      priorities: const TenantPriorities(),
      listing: demoHomeById('lst_match_bandra_rent')!,
      commute: commute,
    );
    expect(cleared.score, base.score);
  });
}
