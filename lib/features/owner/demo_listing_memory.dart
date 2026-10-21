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

  /// Listings this demo session published. The server row can stay a draft.
  final publishedInDemo = <String>{};

  void markPublished(String id) {
    final home = homes[id];
    if (home == null) {
      return;
    }
    home.status = 'published';
    home.publishedUntil ??= DateTime.now().add(const Duration(days: 30));
    home.updatedAt = DateTime.now();
    publishedInDemo.add(id);
  }

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
      updatedAt: DateTime.now().add(const Duration(hours: 1)),
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
        title: '3BHK in Vasant Kunj',
        city: 'Delhi',
        locality: 'Vasant Kunj',
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
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-whitefield',
        title: '2BHK near Whitefield metro',
        city: 'Bengaluru',
        locality: 'Whitefield',
        rentText: '26000',
        depositText: '78000',
        occupancy: 3,
        amenities: ['lift', 'power_backup'],
      ),
      status: 'paused',
      updatedAt: DateTime.now().subtract(const Duration(days: 40)),
      days: demoViewSeries(1),
      saves: 4,
      interests: 2,
      visitRequests: 1,
      publishedUntil: DateTime.now().add(const Duration(days: 21)),
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-bandra',
        title: 'Room in a Bandra West flat',
        city: 'Mumbai',
        locality: 'Bandra West',
        rentText: '32000',
        depositText: '64000',
        furnishing: 'furnished',
        propertyType: 'private_room',
      ),
      status: 'paused',
      updatedAt: DateTime.now().subtract(const Duration(days: 41)),
      days: demoViewSeries(2),
      saves: 5,
      interests: 3,
      visitRequests: 2,
      publishedUntil: DateTime.now().add(const Duration(days: 14)),
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-kothrud',
        title: '1BHK in Kothrud',
        city: 'Pune',
        locality: 'Kothrud',
        rentText: '18000',
        depositText: '36000',
        occupancy: 2,
      ),
      status: 'paused',
      updatedAt: DateTime.now().subtract(const Duration(days: 42)),
      days: demoViewSeries(3),
      saves: 3,
      interests: 1,
      visitRequests: 1,
      publishedUntil: DateTime.now().add(const Duration(days: 12)),
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-vastrapur',
        title: 'Furnished 2BHK in Vastrapur',
        city: 'Ahmedabad',
        locality: 'Vastrapur',
        rentText: '22000',
        depositText: '44000',
        furnishing: 'furnished',
        occupancy: 3,
      ),
      status: 'paused',
      updatedAt: DateTime.now().subtract(const Duration(days: 43)),
      days: demoViewSeries(4),
      saves: 2,
      interests: 2,
      visitRequests: 1,
      publishedUntil: DateTime.now().add(const Duration(days: 16)),
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-dwarka',
        title: '2BHK in Dwarka Sector 12',
        city: 'Delhi',
        locality: 'Dwarka',
        rentText: '30000',
        depositText: '60000',
        occupancy: 3,
      ),
      status: 'paused',
      updatedAt: DateTime.now().subtract(const Duration(days: 44)),
      days: demoViewSeries(5),
      saves: 4,
      interests: 2,
      visitRequests: 1,
      publishedUntil: DateTime.now().add(const Duration(days: 20)),
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-navrangpura',
        title: '1BHK near Navrangpura',
        city: 'Ahmedabad',
        locality: 'Navrangpura',
        rentText: '15000',
        depositText: '30000',
        furnishing: 'unfurnished',
        occupancy: 2,
      ),
      status: 'paused',
      updatedAt: DateTime.now().subtract(const Duration(days: 45)),
      days: demoViewSeries(1),
      saves: 1,
      interests: 1,
      publishedUntil: DateTime.now().add(const Duration(days: 11)),
    ),
    DemoOwnedHome(
      draft: const ListingDraft(
        id: 'demo-own-kharadi',
        title: '3BHK in Kharadi',
        city: 'Pune',
        locality: 'Kharadi',
        rentText: '34000',
        depositText: '68000',
        furnishing: 'furnished',
        occupancy: 4,
      ),
      status: 'paused',
      updatedAt: DateTime.now().subtract(const Duration(days: 46)),
      days: demoViewSeries(2),
      saves: 6,
      interests: 3,
      visitRequests: 2,
      publishedUntil: DateTime.now().add(const Duration(days: 19)),
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
