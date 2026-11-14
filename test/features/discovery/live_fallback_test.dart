import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/demo_discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';

void main() {
  test('a missing live table falls back to sample homes', () async {
    final gateway = GuestBrowseDiscovery(
      _MissingTable(),
      DemoDiscoveryGateway(),
      signedIn: () => true,
    );
    final state = await gateway.load();
    expect(state.sample, isTrue);
    expect(state.listings, isNotEmpty);
    expect(await gateway.likeListing(state.listings.first), isNotEmpty);
  });

  test('a real feed is not marked sample', () async {
    final gateway = GuestBrowseDiscovery(
      _ReadyTable(),
      DemoDiscoveryGateway(),
      signedIn: () => true,
    );
    final state = await gateway.load();
    expect(state.sample, isFalse);
    expect(state.listings.single.id, 'live-home');
  });

  test(
    'a signed-in permission error is not replaced with sample homes',
    () async {
      final gateway = GuestBrowseDiscovery(
        _Denied(),
        DemoDiscoveryGateway(),
        signedIn: () => true,
      );
      await expectLater(gateway.load(), throwsA(isA<DiscoveryFailure>()));
    },
  );
}

class _MissingTable implements DiscoveryGateway {
  @override
  DiscoveryState? get cachedOrNull => null;

  Never _missing() => throw const DiscoveryFailure(
    "Could not find the table 'public.properties' in the schema cache (PGRST205)",
  );

  @override
  Future<DiscoveryState> load() async => _missing();

  @override
  Future<List<Listing>> searchListings(ListingFilters filters) async =>
      _missing();

  @override
  Future<PreciseAddress> preciseAddress(String propertyId) async => _missing();

  @override
  Future<String> likeListing(Listing listing) async => _missing();

  @override
  Future<String> passListing(Listing listing) async => _missing();

  @override
  Future<String> undoListing(Listing listing) async => _missing();

  @override
  Future<String> saveListing(Listing listing) async => _missing();

  @override
  Future<String> unsaveListing(String listingId) async => _missing();

  @override
  Future<String> shareOwnContact(String matchId, String scope) async =>
      _missing();

  @override
  Future<String> stopSharingOwnContact(String matchId) async => _missing();
}

class _ReadyTable implements DiscoveryGateway {
  @override
  DiscoveryState? get cachedOrNull => null;

  @override
  Future<DiscoveryState> load() async {
    return const DiscoveryState(
      listings: [
        Listing(
          id: 'live-home',
          hostUserId: 'host',
          title: 'Live PG',
          city: 'Ahmedabad',
          locality: 'Navrangpura',
          rentInr: 9000,
          depositInr: 18000,
          furnishing: 'furnished',
          propertyType: 'pg',
          hostDisplayName: 'Host',
          amenities: [],
          summary: 'A published home.',
        ),
      ],
    );
  }

  @override
  Future<List<Listing>> searchListings(ListingFilters filters) async =>
      const [];

  @override
  Future<PreciseAddress> preciseAddress(String propertyId) async =>
      const PreciseAddress.hidden();

  @override
  Future<String> likeListing(Listing listing) async => 'saved';

  @override
  Future<String> passListing(Listing listing) async => 'passed';

  @override
  Future<String> undoListing(Listing listing) async => 'undone';

  @override
  Future<String> saveListing(Listing listing) async => 'saved';

  @override
  Future<String> unsaveListing(String listingId) async => 'removed';

  @override
  Future<String> shareOwnContact(String matchId, String scope) async =>
      'shared';

  @override
  Future<String> stopSharingOwnContact(String matchId) async => 'stopped';
}

class _Denied implements DiscoveryGateway {
  @override
  DiscoveryState? get cachedOrNull => null;

  Never _denied() => throw const DiscoveryFailure(
    'permission denied for table properties (42501)',
  );

  @override
  Future<DiscoveryState> load() async => _denied();

  @override
  Future<List<Listing>> searchListings(ListingFilters filters) async =>
      _denied();

  @override
  Future<PreciseAddress> preciseAddress(String propertyId) async => _denied();

  @override
  Future<String> likeListing(Listing listing) async => _denied();

  @override
  Future<String> passListing(Listing listing) async => _denied();

  @override
  Future<String> undoListing(Listing listing) async => _denied();

  @override
  Future<String> saveListing(Listing listing) async => _denied();

  @override
  Future<String> unsaveListing(String listingId) async => _denied();

  @override
  Future<String> shareOwnContact(String matchId, String scope) async =>
      _denied();

  @override
  Future<String> stopSharingOwnContact(String matchId) async => _denied();
}
