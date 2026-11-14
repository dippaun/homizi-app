import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:homizi/features/shared_home/shared_home_catalog.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_repository.dart';

SharedHome _sample(String slug) =>
    sampleSharedHomes.firstWhere((h) => h.id == '$sampleSharedHomePrefix$slug');

void main() {
  final andheri = _sample('andheri-3bhk');
  final powai = _sample('powai-2bhk');
  final hinjewadi = _sample('hinjewadi-4bhk');

  test('the design example: 3 BHK, 1 living, 2 separate rooms vacant', () {
    expect(andheri.tag, '3 BHK – Shared Home');
    expect(andheri.occupancy.livingLine, '1 person');
    expect(andheri.occupancy.vacantLine, '2 rooms (separate)');
    expect(andheri.occupancy.capacityLine, '3 persons');
    expect(andheri.priceLine, '₹12,000 / room');
    expect(andheri.housemate!.displayName, 'Rohit S.');
    expect(canJoinAlone(andheri), isTrue);
    expect(maxGroupSize(andheri), 2);
  });

  test('single occupancy needs a separate free room per person', () {
    const one = OccupancyNeed();
    const three = OccupancyNeed(mode: JoinMode.group, groupSize: 3);
    expect(fitFor(andheri, one).fits, isTrue);
    expect(fitFor(andheri, three).fits, isFalse);
    expect(fitFor(andheri, three).line, 'Only 2 rooms free; you need 3.');
    expect(fitFor(hinjewadi, one).fits, isTrue);
    expect(
      fitFor(hinjewadi, const OccupancyNeed(mode: JoinMode.group)).fits,
      isFalse,
    );
  });

  test('double occupancy fits only homes that share rooms', () {
    const pair = OccupancyNeed(
      mode: JoinMode.group,
      occupancy: DesiredOccupancy.double,
    );
    expect(fitFor(andheri, pair).fits, isFalse);
    expect(fitFor(powai, pair).fits, isTrue);
    expect(powai.priceLine, '₹8,000 / person');
    expect(powai.shareFor(DesiredOccupancy.double), 8000);
    // One person taking a whole double room pays both places.
    expect(powai.shareFor(DesiredOccupancy.single), 16000);
    expect(maxGroupSize(powai), 3);
  });

  test('unconfirmed homes are kept and say so', () {
    final listing = andheri.listing;
    final unknown = SharedHome(
      listing: listing,
      occupancy: const HomeOccupancy(totalRooms: 3, totalCapacity: 3),
    );
    final fit = fitFor(unknown, const OccupancyNeed());
    expect(fit.fits, isTrue);
    expect(fit.line, contains('not shared'));
    expect(unknown.occupancy.vacantLine, 'Ask the host');
    expect(maxGroupSize(unknown), 0);
  });

  test('join checks compare budget, food, occupation, gender and age', () {
    final need = OccupancyNeed(moveIn: DateTime(2026, 12, 15));
    final checks = joinChecks(andheri, need);
    expect(checks.map((c) => c.label), [
      'Budget match (₹12K)',
      'Food preference (Vegetarian)',
      'Working professional',
      'Male | Age compatible',
      'Free from 1 Dec 2026',
    ]);
    expect(checks.every((c) => c.ok), isTrue);

    final strict = need.copyWith(
      budgetMaxInr: 10000,
      housemateGender: 'female',
      occupation: 'Student',
    );
    final failed = {for (final c in joinChecks(andheri, strict)) c.label: c.ok};
    expect(failed['Budget match (₹12K)'], isFalse);
    expect(failed['Working professional'], isFalse);
    expect(failed['Male | Age compatible'], isFalse);
  });

  test('food fit', () {
    expect(foodFits('veg', 'non_veg'), isFalse);
    expect(foodFits('veg', 'veg'), isTrue);
    expect(foodFits('eggetarian', 'veg'), isTrue);
    expect(foodFits('eggetarian', 'non_veg'), isFalse);
    expect(foodFits('non_veg', 'veg'), isTrue);
    expect(foodFits('any', 'non_veg'), isTrue);
  });

  test('need validation and JSON round trip', () {
    expect(const OccupancyNeed(budgetMinInr: 30000).problem, isNotNull);
    expect(const OccupancyNeed(locality: '').problem, isNotNull);
    expect(const OccupancyNeed().problem, isNull);
    final need = OccupancyNeed(
      mode: JoinMode.group,
      groupSize: 3,
      occupancy: DesiredOccupancy.flexible,
      moveIn: DateTime(2026, 12, 15),
      food: 'non_veg',
    );
    final back = OccupancyNeed.decode(need.encode())!;
    expect(back.mode, JoinMode.group);
    expect(back.groupSize, 3);
    expect(back.occupancy, DesiredOccupancy.flexible);
    expect(back.moveIn, DateTime(2026, 12, 15));
    expect(back.food, 'non_veg');
    expect(back.saved, isTrue);
    expect(need.city, 'Mumbai');
    expect(need.area, 'Andheri East');
  });

  test('host details validation', () {
    const ok = HomeOccupancy(
      totalRooms: 3,
      totalCapacity: 3,
      currentlyLiving: 1,
      vacantRooms: 2,
      housemates: [Housemate(firstName: 'Rohit')],
    );
    expect(ok.problem, isNull);
    expect(
      const HomeOccupancy(
        totalRooms: 2,
        totalCapacity: 2,
        currentlyLiving: 0,
        vacantRooms: 3,
      ).problem,
      contains('Vacant rooms'),
    );
    expect(
      const HomeOccupancy(
        totalRooms: 3,
        totalCapacity: 3,
        currentlyLiving: 1,
        vacantRooms: 2,
      ).problem,
      contains('first name'),
    );
    expect(
      const HomeOccupancy(
        totalRooms: 2,
        totalCapacity: 2,
        currentlyLiving: 2,
        vacantRooms: 1,
        housemates: [Housemate(firstName: 'A')],
      ).problem,
      contains('full'),
    );
    final back = HomeOccupancy.fromJson(ok.toJson());
    expect(back.vacantRooms, 2);
    expect(back.housemates.single.firstName, 'Rohit');
  });

  test('join request JSON round trip', () {
    final request = JoinRequest(
      id: 'r1',
      homeId: andheri.id,
      homeTitle: andheri.listing.title,
      homeTag: andheri.tag,
      place: andheri.place,
      hostName: 'Rohit S.',
      mode: JoinMode.group,
      people: 2,
      shareInr: 12000,
      sentAt: DateTime(2026, 11, 14, 19),
      sample: true,
      status: JoinStatus.accepted,
    );
    final back = decodeJoinRequests(encodeJoinRequests([request])).single;
    expect(back.status, JoinStatus.accepted);
    expect(back.people, 2);
    expect(back.sample, isTrue);
    expect(back.open, isTrue);
    expect(decodeJoinRequests('nope'), isEmpty);
  });

  test('ranking puts fitting homes first, then the asked locality', () {
    ListingMatch score(SharedHome home) => const ListingMatch.hidden();
    final rows = rankSharedHomes(
      sampleSharedHomes,
      const OccupancyNeed(mode: JoinMode.group),
      score,
    );
    expect(rows.first.home.id, andheri.id);
    final firstMiss = rows.indexWhere((r) => !r.fit.fits);
    expect(rows.skip(firstMiss).every((r) => !r.fit.fits), isTrue);
  });

  test('shared home listings', () {
    Listing make(String type, String host) => Listing(
      id: 'x',
      hostUserId: 'h',
      title: 't',
      city: 'Pune',
      locality: 'Baner',
      rentInr: 1,
      depositInr: 0,
      furnishing: 'furnished',
      propertyType: type,
      hostDisplayName: 'h',
      amenities: const [],
      summary: '',
      hostKind: host,
    );
    expect(isSharedHomeListing(make('room_in_3bhk', 'Owner')), isTrue);
    expect(isSharedHomeListing(make('apartment', 'Flatmate')), isTrue);
    expect(isSharedHomeListing(make('private_room', 'Owner')), isTrue);
    expect(isSharedHomeListing(make('apartment', 'Owner')), isFalse);
  });

  test('host details save on the device when the table is missing', () async {
    final local = MemorySharedHomeLocal();
    final repo = SharedHomeRepository(
      local: local,
      remote: const SkippingSharedHomeRemote(),
    );
    final saved = await repo.saveDetails(
      listingId: 'l1',
      label: '3 BHK',
      occupancy: andheri.occupancy,
    );
    expect(saved, isFalse);
    final back = await repo.readLocalDetails();
    expect(back['l1']!.vacantRooms, 2);
  });

  test('sample data is labelled and carries no contact details', () {
    for (final home in sampleSharedHomes) {
      expect(home.sample, isTrue);
      expect(isSampleSharedHome(home.id), isTrue);
      expect(home.listing.summary, contains('Sample home'));
      final text = home.occupancy.toJson().toString();
      expect(text, isNot(contains('@')));
      expect(RegExp('[0-9]{10}').hasMatch(text), isFalse);
    }
  });
}
