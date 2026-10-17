import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';

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
        furnishing: 'gold',
        lifestyle: ['caste'],
      );
      final issues = draft.errors(today: today);
      expect(issues, contains('Choose a property type.'));
      expect(issues, contains('Choose a furnishing.'));
      expect(issues, contains('Choose lifestyle notes from the list.'));

      final edited = draft.copyWith(
        propertyType: 'apartment',
        furnishing: 'furnished',
        lifestyle: const ['wfh', 'non_smoker'],
      );
      expect(edited.errors(today: today), isEmpty);
      expect(edited.lifestyle, ['wfh', 'non_smoker']);
    },
  );

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
