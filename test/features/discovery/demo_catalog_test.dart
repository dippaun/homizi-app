import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';

void main() {
  test('demo homes cover the city brief without contact fields', () {
    expect(DemoCatalog.byId('lst_koramangala')!.rentInr, 22000);
    expect(DemoCatalog.byId('lst_koramangala')!.locality, 'Koramangala');
    expect(DemoCatalog.byId('lst_indiranagar')!.rentInr, 28000);
    expect(DemoCatalog.byId('lst_kothrud')!.furnishing, 'unfurnished');

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
    }
  });
}
