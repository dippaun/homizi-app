import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/roles/requirement_match.dart';

void main() {
  test('any selected room or furnishing matches, and empty matches all', () {
    expect(_score(), 100);
    expect(_score(rooms: const ['shared'], furns: const ['unfurnished']), 75);
    expect(
      _score(
        rooms: const ['1bhk', '2bhk'],
        furns: const ['furnished', 'semi_furnished'],
      ),
      100,
    );
    expect(_score(furns: const ['any']), 100);
    expect(_score(rooms: const ['no_preference']), 100);
    expect(_score(furns: const ['none']), 90);
    expect(
      _score(roomType: '1bhk', requirementFurnishing: 'semi_furnished'),
      100,
    );
  });
}

int _score({
  List<String> rooms = const [],
  List<String> furns = const [],
  String roomType = '',
  String requirementFurnishing = '',
}) {
  return requirementListingMatch(
    listingCity: 'Pune',
    listingLocality: 'Baner',
    rentInr: 18000,
    propertyType: 'apartment',
    furnishing: 'semi_furnished',
    listingAmenities: const [],
    requirementCity: 'Pune',
    requirementLocalities: const ['Baner'],
    budgetMinInr: 10000,
    budgetMaxInr: 20000,
    roomType: roomType,
    roomTypes: rooms,
    propertyTypes: const ['apartment'],
    requirementFurnishing: requirementFurnishing,
    requirementFurnishings: furns,
    requirementAmenities: const [],
  );
}
