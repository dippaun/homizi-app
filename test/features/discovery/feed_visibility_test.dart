import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/discovery/domain/feed_visibility.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

void main() {
  test('a fresh tenant with no preferences still sees all 40 homes', () {
    final published = [
      for (var index = 0; index < 40; index++)
        Listing(
          id: 'home-$index',
          hostUserId: 'host',
          title: 'Home $index',
          city: index.isEven ? 'Delhi NCR' : 'Bengaluru',
          locality: 'Locality $index',
          rentInr: 8000 + index * 500,
          depositInr: 16000,
          furnishing: 'semi_furnished',
          propertyType: index.isEven ? 'private_room' : 'apartment',
          hostDisplayName: 'Host',
          amenities: const [],
          summary: 'Published home.',
        ),
    ];

    expect(listingsVisibleToTenant(published), hasLength(40));
    expect(
      listingsVisibleToTenant(
        published,
        preferences: const TenantPreferences(),
      ),
      hasLength(40),
    );
    expect(
      listingsVisibleToTenant(
        published,
        preferences: const TenantPreferences(
          budgetMinInr: 10000,
          budgetMaxInr: 20000,
          localities: ['Koramangala'],
          propertyTypes: ['apartment'],
        ),
      ),
      hasLength(40),
    );
  });
}
