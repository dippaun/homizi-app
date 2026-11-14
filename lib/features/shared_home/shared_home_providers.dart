import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:homizi/features/shared_home/shared_home_catalog.dart';
import 'package:homizi/features/shared_home/shared_home_repository.dart';

/// Homes with a room for a flatmate: shared rooms, rooms in a BHK, private
/// rooms in a shared flat, or a flatmate host.
bool isSharedHomeListing(Listing listing) {
  final type = listing.propertyType.toLowerCase();
  final host = listing.hostKind.toLowerCase();
  return type == 'shared_room' ||
      type == 'shared' ||
      type == 'private_room' ||
      type.startsWith('room_in_') ||
      host == 'flatmate';
}

final sharedHomeRepositoryProvider = Provider<SharedHomeRepository>((ref) {
  final config = ref.watch(appConfigProvider);
  final demo = ref.watch(forceDemoModeProvider);
  return SharedHomeRepository(
    local: DeviceSharedHomeLocal(),
    remote: config.connectsToSupabase && !demo
        ? const SupabaseSharedHomeRemote()
        : const SkippingSharedHomeRemote(),
  );
});

/// The seeker's saved occupancy need. Sample values until they save.
final occupancyNeedProvider =
    NotifierProvider<OccupancyNeedController, OccupancyNeed>(
      OccupancyNeedController.new,
    );

class OccupancyNeedController extends Notifier<OccupancyNeed> {
  @override
  OccupancyNeed build() {
    unawaited(_load());
    return OccupancyNeed(moveIn: DateTime(2026, 12, 15));
  }

  Future<void> _load() async {
    final saved = await ref.read(sharedHomeRepositoryProvider).readNeed();
    if (saved != null) {
      state = saved;
    }
  }

  Future<void> save(OccupancyNeed need) async {
    state = need.copyWith(saved: true);
    await ref.read(sharedHomeRepositoryProvider).saveNeed(state);
  }
}

/// Server or device occupancy details for real listings, by listing id.
final sharedHomeDetailsProvider = FutureProvider<Map<String, HomeOccupancy>>((
  ref,
) async {
  final repo = ref.watch(sharedHomeRepositoryProvider);
  final listings = ref.watch(discoveryProvider.select((s) => s.listings));
  final ids = [
    for (final listing in listings)
      if (isSharedHomeListing(listing)) listing.id,
  ];
  final local = await repo.readLocalDetails();
  final remote = await repo.remote.details(ids);
  return {...local, ...remote};
});

class SharedHomesState {
  const SharedHomesState({
    required this.homes,
    required this.loading,
    this.error,
  });

  final List<SharedHome> homes;
  final bool loading;
  final String? error;

  SharedHome? byId(String id) {
    for (final home in homes) {
      if (home.id == id) {
        return home;
      }
    }
    return null;
  }
}

/// Real shared listings from discovery, then the sample homes.
final sharedHomesProvider = Provider<SharedHomesState>((ref) {
  final discovery = ref.watch(discoveryProvider);
  final details = ref.watch(sharedHomeDetailsProvider).asData?.value ?? {};
  final real = [
    for (final listing in discovery.listings)
      if (isSharedHomeListing(listing))
        SharedHome(
          listing: listing,
          occupancy:
              details[listing.id] ??
              HomeOccupancy(
                totalRooms: listing.bedrooms < 1 ? 1 : listing.bedrooms,
                totalCapacity: listing.occupancyMax < 1
                    ? 1
                    : listing.occupancyMax,
              ),
        ),
  ];
  return SharedHomesState(
    homes: [...real, ...sampleSharedHomes],
    loading: discovery.loading && discovery.listings.isEmpty,
    error: discovery.listings.isEmpty ? discovery.error : null,
  );
});

/// The one match % for a shared home: the shared listing scorer (#75), so
/// the card, the detail screen and the full listing all agree.
final sharedHomeScoreProvider = Provider<ListingMatch Function(SharedHome)>((
  ref,
) {
  final score = ref.watch(listingScorerProvider);
  return (home) => score(home.listing);
});

class RankedHome {
  const RankedHome({
    required this.home,
    required this.fit,
    required this.match,
  });

  final SharedHome home;
  final HomeFit fit;
  final ListingMatch match;
}

/// Homes that fit first, then by match %, then by price.
List<RankedHome> rankSharedHomes(
  List<SharedHome> homes,
  OccupancyNeed need,
  ListingMatch Function(SharedHome) score,
) {
  final rows = [
    for (final home in homes)
      RankedHome(home: home, fit: fitFor(home, need), match: score(home)),
  ];
  int area(SharedHome home) {
    final wanted = need.area.toLowerCase();
    if (wanted.isEmpty) {
      return 1;
    }
    if (home.listing.locality.toLowerCase() == wanted) {
      return 0;
    }
    final city = need.city.toLowerCase();
    return city.isNotEmpty && home.listing.city.toLowerCase() == city ? 1 : 2;
  }

  rows.sort((a, b) {
    // Confirmed fits first, then homes whose host has not shared rooms yet.
    int tier(RankedHome row) => !row.fit.fits
        ? 2
        : row.home.occupancy.confirmed
        ? 0
        : 1;
    final fit = tier(a).compareTo(tier(b));
    if (fit != 0) {
      return fit;
    }
    final place = area(a.home).compareTo(area(b.home));
    if (place != 0) {
      return place;
    }
    final match = b.match.score.compareTo(a.match.score);
    if (match != 0) {
      return match;
    }
    return a.home.placeInr.compareTo(b.home.placeInr);
  });
  return rows;
}

/// The match with this home's host, when the host accepted interest.
MatchSummary? matchWithHost(DiscoveryState discovery, SharedHome home) {
  final host = home.listing.hostUserId;
  if (host.isEmpty) {
    return null;
  }
  for (final match in discovery.matches) {
    if (match.otherUserId == host) {
      return match;
    }
  }
  return null;
}

class JoinResult {
  const JoinResult({this.request, this.problem});

  final JoinRequest? request;
  final String? problem;
}

final joinRequestsProvider =
    NotifierProvider<JoinRequestsController, List<JoinRequest>>(
      JoinRequestsController.new,
    );

class JoinRequestsController extends Notifier<List<JoinRequest>> {
  @override
  List<JoinRequest> build() {
    unawaited(load());
    return const [];
  }

  SharedHomeRepository get _repo => ref.read(sharedHomeRepositoryProvider);

  Future<void> load() async {
    final rows = await _repo.readRequests();
    // Anything sent while the device copy was loading wins.
    final known = {for (final row in state) row.id};
    state = [...state, ...rows.where((row) => !known.contains(row.id))];
  }

  JoinRequest? byId(String id) {
    for (final row in state) {
      if (row.id == id) {
        return row;
      }
    }
    return null;
  }

  /// The open request for [homeId], if any.
  JoinRequest? openFor(String homeId) {
    for (final row in state) {
      if (row.homeId == homeId && row.open) {
        return row;
      }
    }
    return null;
  }

  Future<void> _put(JoinRequest request) async {
    final next = [request, ...state.where((row) => row.id != request.id)];
    state = next;
    await _repo.writeRequests(next);
  }

  /// Sends interest for a real home (the host sees it under Interested
  /// seekers) and records the join details. Sample homes send nothing.
  Future<JoinResult> send({
    required SharedHome home,
    required OccupancyNeed need,
    required JoinMode mode,
    required int people,
    required String firstName,
  }) async {
    final existing = openFor(home.id);
    if (existing != null) {
      return JoinResult(request: existing);
    }
    if (!home.sample) {
      final notice = await ref.read(discoveryProvider.notifier).like(home.id);
      if (!notice.ok) {
        return JoinResult(problem: notice.message);
      }
    }
    final share = home.shareFor(need.occupancy);
    var request = JoinRequest(
      id: newLocalId(),
      homeId: home.id,
      homeTitle: home.listing.title,
      homeTag: home.tag,
      place: home.place,
      hostName: home.hostName,
      mode: mode,
      people: people,
      shareInr: share,
      sentAt: DateTime.now(),
      sample: home.sample,
      moveIn: need.moveIn,
    );
    if (!home.sample) {
      final saved = await _repo.remote.sendRequest(
        request: request,
        firstName: firstName.trim().isEmpty ? 'A HOMIZI member' : firstName,
      );
      request = request.copyWith(savedToAccount: saved);
    }
    await _put(request);
    return JoinResult(request: request);
  }

  /// Reads the host's answer: the server row when the table exists, or a
  /// match with the host (they accepted the interest).
  Future<JoinRequest?> refresh(String id, {SharedHome? home}) async {
    final request = byId(id);
    if (request == null || request.sample) {
      return request;
    }
    var next = request;
    final statuses = await _repo.remote.myStatuses();
    final remote = statuses?[id];
    if (remote != null && remote != request.status) {
      next = next.copyWith(status: remote, decidedAt: DateTime.now());
    }
    if (next.status == JoinStatus.pending && home != null) {
      final match = matchWithHost(ref.read(discoveryProvider), home);
      if (match != null) {
        next = next.copyWith(
          status: JoinStatus.accepted,
          decidedAt: DateTime.now(),
        );
      }
    }
    if (!identical(next, request)) {
      await _put(next);
    }
    return next;
  }

  /// SAMPLE ONLY: the seeded housemate's reply, so the rest of the flow can
  /// be tried. Real homes wait for the host.
  Future<JoinRequest?> sampleReply(String id) async {
    final request = byId(id);
    if (request == null || !request.sample) {
      return request;
    }
    final next = request.copyWith(
      status: JoinStatus.accepted,
      decidedAt: DateTime.now(),
    );
    await _put(next);
    return next;
  }

  Future<JoinRequest?> moveIn(String id) => _set(id, JoinStatus.movedIn);

  Future<JoinRequest?> withdraw(String id) => _set(id, JoinStatus.withdrawn);

  Future<JoinRequest?> _set(String id, JoinStatus status) async {
    final request = byId(id);
    if (request == null) {
      return null;
    }
    final next = request.copyWith(
      status: status,
      movedInAt: status == JoinStatus.movedIn ? DateTime.now() : null,
    );
    if (request.savedToAccount) {
      await _repo.remote.setStatus(id, status);
    }
    await _put(next);
    return next;
  }
}
