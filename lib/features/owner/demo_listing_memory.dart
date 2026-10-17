import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// Device-only owner listings shared by the demo inventory and owner gateways.
class DemoOwnedHome {
  DemoOwnedHome({
    required this.draft,
    required this.status,
    required this.days,
    this.saves = 0,
    this.interests = 0,
    this.visitRequests = 0,
    this.publishedUntil,
    this.replyHours,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  ListingDraft draft;
  String status;
  List<DayCount> days;
  int saves;
  int interests;
  int visitRequests;
  DateTime? publishedUntil;
  int? replyHours;
  DateTime updatedAt;

  String get id => draft.id ?? '';

  int get views {
    var total = 0;
    for (final day in days) {
      total += day.views;
    }
    return total;
  }
}

class DemoListingMemory {
  DemoListingMemory({List<DemoOwnedHome>? seed, this.idVerifiedDemo = false}) {
    for (final home in seed ?? const <DemoOwnedHome>[]) {
      if (home.id.isNotEmpty) {
        homes[home.id] = home;
      }
    }
  }

  final homes = <String, DemoOwnedHome>{};
  bool idVerifiedDemo;

  DemoOwnedHome? byId(String id) => homes[id];

  DemoOwnedHome? latestDraft() {
    DemoOwnedHome? found;
    for (final home in homes.values) {
      if (home.status != 'draft') {
        continue;
      }
      if (found == null || home.updatedAt.isAfter(found.updatedAt)) {
        found = home;
      }
    }
    return found;
  }

  void upsertDraft(ListingDraft draft) {
    final id = draft.id;
    if (id == null || id.isEmpty) {
      return;
    }
    final existing = homes[id];
    if (existing == null) {
      homes[id] = DemoOwnedHome(
        draft: draft,
        status: 'draft',
        days: demoViewSeries(1),
      );
      return;
    }
    existing.draft = draft;
    existing.updatedAt = DateTime.now();
  }

  UserBadges get myBadges => UserBadges(
    phoneVerified: true,
    emailVerified: true,
    profileComplete: true,
    idVerifiedDemo: idVerifiedDemo,
  );
}

/// Thirty days ending today. The pattern is fixed so tests can read it.
List<DayCount> demoViewSeries(int salt) {
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day);
  return [
    for (var offset = 29; offset >= 0; offset--)
      DayCount(
        day: start.subtract(Duration(days: offset)),
        views: (offset + salt) % 6,
      ),
  ];
}

List<DemoOwnedHome> demoOwnerSeed() {
  return [
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-koramangala',
        title: '2BHK near Sony Signal, Koramangala',
        city: 'Bengaluru',
        locality: 'Koramangala',
        rentText: '28000',
        depositText: '84000',
        maintenanceText: '2000',
        occupancy: 3,
        amenities: ['lift', 'parking', 'power_backup'],
        restrictions: ['no_smoking'],
        suitability: ['family', 'working_professionals'],
      ),
      status: 'published',
      days: demoViewSeries(2),
      saves: 6,
      interests: 4,
      visitRequests: 2,
      publishedUntil: DateTime.now().add(const Duration(days: 18)),
      replyHours: 3,
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-baner',
        title: 'Furnished room in a Baner flat',
        city: 'Pune',
        locality: 'Baner',
        rentText: '14000',
        depositText: '28000',
        furnishing: 'furnished',
        propertyType: 'private_room',
        amenities: ['wifi', 'washing_machine'],
        suitability: ['working_professionals'],
      ),
      status: 'paused',
      days: demoViewSeries(4),
      saves: 2,
      interests: 1,
      publishedUntil: DateTime.now().add(const Duration(days: 9)),
      replyHours: 5,
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-indiranagar',
        title: '1BHK in Indiranagar',
        city: 'Bengaluru',
        locality: 'Indiranagar',
        rentText: '32000',
        depositText: '96000',
        furnishing: 'furnished',
        occupancy: 2,
        amenities: ['lift', 'gym'],
        suitability: ['couple'],
      ),
      status: 'in_review',
      days: demoViewSeries(0),
      saves: 1,
      replyHours: 2,
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-andheri',
        title: 'Quiet 1BHK draft in Andheri West',
        city: 'Mumbai',
        locality: 'Andheri West',
        rentText: '42000',
        depositText: '126000',
        occupancy: 2,
      ),
      status: 'draft',
      days: const [],
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-jubilee',
        title: '3BHK let in Jubilee Hills',
        city: 'Hyderabad',
        locality: 'Jubilee Hills',
        rentText: '55000',
        depositText: '165000',
        furnishing: 'furnished',
        occupancy: 4,
        suitability: ['family'],
      ),
      status: 'rented',
      days: demoViewSeries(3),
      saves: 8,
      interests: 5,
      visitRequests: 3,
      publishedUntil: DateTime.now().subtract(const Duration(days: 4)),
      replyHours: 4,
    ),
  ];
}

String demoChipForStatus(String status) {
  return switch (status) {
    'published' => 'live',
    'in_review' => 'in_review',
    'paused' => 'paused',
    'rented' => 'rented',
    'expired' => 'expired',
    _ => 'draft',
  };
}

OwnerListing demoOwnerListing(DemoOwnedHome home) {
  return OwnerListing(
    id: home.id,
    title: home.draft.title,
    locality: home.draft.locality,
    city: home.draft.city,
    rentInr: home.draft.rentInr ?? 0,
    status: home.status,
    chip: demoChipForStatus(home.status),
    views: home.views,
    saves: home.saves,
    interests: home.interests,
    visitRequests: home.visitRequests,
    publishedUntil: home.publishedUntil,
  );
}

final demoListingMemoryProvider = Provider<DemoListingMemory>((ref) {
  return DemoListingMemory(seed: demoOwnerSeed());
});
