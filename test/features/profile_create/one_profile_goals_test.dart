import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';

void main() {
  test('first-login goals reuse the existing role values', () {
    expect(rolesForGoals(['finder', 'host']), ['tenant', 'host']);
    expect(goalTagsFor(['finder', 'sharer']), [sharerGoalTag, roommateGoalTag]);
    expect(goalsPublishRoommate(['sharer'], const []), isTrue);
    expect(goalsPublishRoommate(const ['tenant'], const []), isFalse);
    expect(
      goalsFromProfile(
        roles: const ['tenant'],
        tags: const [roommateGoalTag, hostGoalTag],
      ),
      {'finder', 'host'},
    );
  });

  test('a mistyped city matches the catalogue city', () {
    const places = [
      PlaceSuggestion(label: 'Ahmedabad', city: 'Ahmedabad'),
      PlaceSuggestion(label: 'Mumbai', city: 'Mumbai'),
    ];
    expect(closestCatalogPlace('ahmedbad', places)?.label, 'Ahmedabad');
    expect(closestCatalogPlace('mumb', places)?.label, 'Mumbai');
    expect(closestCatalogPlace('zz', places), isNull);
  });
}
