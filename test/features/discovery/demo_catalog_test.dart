import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';

void main() {
  test('demo homes cover the city brief without contact fields', () {
    expect(DemoCatalog.listings, hasLength(40));
    expect(DemoCatalog.listings.first.id, 'lst_koramangala');
    expect(DemoCatalog.byId('lst_koramangala')!.rentInr, 22000);
    expect(DemoCatalog.byId('lst_koramangala')!.locality, 'Koramangala');
    expect(DemoCatalog.byId('lst_koramangala')!.demoReciprocal, isTrue);
    expect(
      DemoCatalog.listings.where((listing) => listing.demoReciprocal),
      hasLength(1),
    );
    expect(DemoCatalog.byId('lst_indiranagar')!.rentInr, 28000);
    expect(DemoCatalog.byId('lst_kothrud')!.furnishing, 'unfurnished');
    expect(DemoCatalog.byId('lst_kothrud')!.title, 'Shared room in Kothrud');
    final ids = DemoCatalog.listings.map((listing) => listing.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(
      ids.indexOf('lst_kothrud'),
      lessThan(ids.indexOf('lst_kothrud_room')),
    );

    final cities = DemoCatalog.listings.map((listing) => listing.city).toSet();
    expect(
      cities,
      containsAll(['Bengaluru', 'Pune', 'Mumbai', 'Hyderabad', 'Delhi NCR']),
    );
    final localities = DemoCatalog.listings
        .map((listing) => listing.locality)
        .toSet();
    expect(
      localities,
      containsAll([
        'Koramangala',
        'HSR Layout',
        'Indiranagar',
        'Baner',
        'Kharadi',
        'Andheri West',
        'Powai',
        'Gachibowli',
        'Gurugram',
        'Whitefield',
        'Jayanagar',
        'Bellandur',
        'Marathahalli',
        'JP Nagar',
        'Hebbal',
        'BTM Layout',
        'Electronic City',
        'Viman Nagar',
        'Wakad',
        'Hinjewadi',
        'Koregaon Park',
        'Aundh',
        'Bandra West',
        'Goregaon East',
        'Chembur',
        'Thane',
        'Mulund',
        'Malad West',
        'Madhapur',
        'Kondapur',
        'Hitech City',
        'Banjara Hills',
        'Kukatpally',
        'Noida Sector 62',
        'Dwarka',
        'Saket',
        'Greater Noida',
        'Indirapuram',
      ]),
    );
    final bhks = DemoCatalog.listings
        .map((listing) => listing.bedrooms)
        .toSet();
    expect(bhks, containsAll([1, 2, 3]));
    for (final listing in DemoCatalog.listings) {
      expect(listing.photoAssets, isNotEmpty);
      final json = listing.toPublicJson();
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('addressLine'), isFalse);
      final blob =
          '${listing.title} ${listing.summary} ${listing.hostDisplayName}'
              .toLowerCase();
      expect(blob.contains('@'), isFalse);
      expect(blob.contains('+91'), isFalse);
      expect(blob.contains('phone'), isFalse);
    }
  });
}
