import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_payload.dart';

void main() {
  final today = DateTime(2026, 10, 11);

  test('rejects an inverted budget and a past move-in date', () {
    const draft = RequirementDraft(
      budgetMinInr: 30000,
      budgetMaxInr: 10000,
      city: 'Pune',
      locality: 'Baner',
    );
    expect(
      draft.errors(today: today),
      contains('Minimum budget cannot exceed the maximum.'),
    );

    final past = RequirementDraft(
      budgetMinInr: 10000,
      budgetMaxInr: 20000,
      city: 'Pune',
      locality: 'Baner',
      moveInDate: DateTime(2026, 10),
    );
    expect(
      past.errors(today: today),
      contains('Move-in date cannot be in the past.'),
    );
  });

  test(
    'property type, furnishing, and lifestyle are part of a requirement',
    () {
      const draft = RequirementDraft(
        budgetMinInr: 15000,
        budgetMaxInr: 25000,
        city: 'Bengaluru',
        locality: 'Koramangala',
        propertyType: 'castle',
        furnishings: ['gold'],
        lifestyle: ['caste'],
      );
      final issues = draft.errors(today: today);
      expect(issues, contains('Choose a property type.'));
      expect(issues, contains('Choose a furnishing.'));
      expect(issues, contains('Choose lifestyle notes from the list.'));

      final edited = draft.copyWith(
        propertyType: 'apartment',
        furnishings: ['furnished'],
        lifestyle: const ['wfh', 'non_smoker'],
      );
      expect(edited.errors(today: today), isEmpty);
      expect(edited.lifestyle, ['wfh', 'non_smoker']);
    },
  );

  test('an exclusive choice clears the other chips, and the reverse', () {
    expect(
      toggleRequirementChoice(
        selected: const ['four_wheeler', 'either'],
        value: 'none',
        options: requirementParkingNeeds,
      ),
      ['none'],
    );
    expect(
      toggleRequirementChoice(
        selected: const ['none'],
        value: 'four_wheeler',
        options: requirementParkingNeeds,
      ),
      ['four_wheeler'],
    );
    expect(
      toggleRequirementChoice(
        selected: const ['none'],
        value: 'none',
        options: requirementParkingNeeds,
      ),
      isEmpty,
    );
    expect(
      toggleRequirementChoice(
        selected: const ['any'],
        value: 'ground',
        options: requirementFloors,
      ),
      ['ground'],
    );
    expect(
      toggleRequirementChoice(
        selected: const ['ground', 'high'],
        value: 'any',
        options: requirementFloors,
      ),
      ['any'],
    );
    expect(
      toggleRequirementChoice(
        selected: const ['low', 'high'],
        value: 'mid',
        options: requirementFloors,
      ),
      ['low', 'mid', 'high'],
    );
    expect(exclusiveRequirementOption(requirementHabits), isNull);
    expect(
      toggleRequirementChoice(
        selected: const ['no'],
        value: 'occasionally',
        options: requirementHabits,
      ),
      ['no', 'occasionally'],
    );
  });

  test('a stored string is one choice and review joins several labels', () {
    final draft = requirementDraftFromRow(const {
      'room_type': '1bhk',
      'furnishing': 'furnished',
      'parking_need': 'none',
      'preferred_floor': ['any'],
      'food_habit': ['veg', 'eggetarian', 'gold'],
      'gender_preference': 'women',
      'occupancy_preference': 'shared',
    });
    expect(draft.roomTypes, ['1bhk']);
    expect(draft.furnishings, ['furnished']);
    expect(draft.parkingNeeds, ['none']);
    expect(draft.preferredFloors, ['any']);
    expect(draft.foodHabits, ['veg', 'eggetarian']);
    expect(draft.genderPreference, 'women');
    expect(draft.occupancyPreference, 'shared');
    expect(
      joinRequirementLabels(const [
        'shared',
        '1bhk',
        '2bhk',
      ], requirementRoomTypeLabel),
      'Shared room, 1 BHK, 2 BHK',
    );
    expect(
      joinRequirementLabels(draft.furnishings, requirementFurnishingLabel),
      'Furnished',
    );

    final payload = requirementUpdatePayload(draft);
    expect(payload['room_type'], ['1bhk']);
    expect(payload['furnishing'], ['furnished']);
    expect(payload['food_habit'], ['veg', 'eggetarian']);
    expect(payload['gender_preference'], 'women');
    expect(payload['occupancy_preference'], 'shared');
  });

  test('a complete requirement has no errors', () {
    final draft = RequirementDraft(
      budgetMinInr: 15000,
      budgetMaxInr: 25000,
      city: 'Bengaluru',
      locality: 'Koramangala',
      moveInDate: DateTime(2026, 11),
    );
    expect(draft.errors(today: today), isEmpty);
  });

  test('publish stays blocked until three photos and a rent exist', () {
    const draft = ListingDraft(
      title: 'Room',
      city: 'Pune',
      locality: 'Baner',
      rentText: '0',
      photos: [
        PhotoSlot(label: 'Living room', isPrimary: true),
        PhotoSlot(label: 'Bedroom', isPrimary: false),
      ],
    );
    expect(draft.persistBlockers(), isEmpty);
    expect(
      draft.publishBlockers(),
      contains('Enter a monthly rent in rupees.'),
    );
    expect(draft.publishBlockers(), contains('Add at least 3 photos.'));
  });
}
