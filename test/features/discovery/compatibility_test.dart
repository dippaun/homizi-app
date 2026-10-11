import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/compatibility.dart';

void main() {
  const preference = CompatibilityPreference(
    budgetMinInr: 15000,
    budgetMaxInr: 25000,
    city: 'Bengaluru',
    locality: 'Koramangala',
    furnishing: 'furnished',
    propertyType: 'apartment',
  );

  test('a matching home scores 100', () {
    final listing = DemoCatalog.byId('lst_koramangala')!;
    final result = scoreCompatibility(preference: preference, listing: listing);
    expect(result.score, 100);
    expect(result.reasons, contains('Rent sits inside your budget.'));
  });

  test(
    'a different city and type lowers the score without using protected traits',
    () {
      final listing = DemoCatalog.byId('lst_kothrud')!;
      final result = scoreCompatibility(
        preference: preference,
        listing: listing,
      );
      expect(result.score, lessThan(40));
      final joined = result.reasons.join(' ').toLowerCase();
      expect(joined.contains('religion'), isFalse);
      expect(joined.contains('caste'), isFalse);
      expect(joined.contains('gender'), isFalse);
    },
  );

  test('rent just outside the budget is a partial score', () {
    final listing = DemoCatalog.byId('lst_indiranagar')!;
    final result = scoreCompatibility(preference: preference, listing: listing);
    expect(result.reasons, contains('Rent is close to your budget.'));
    expect(result.score, 15 + 25 + 0 + 10 + 0);
  });
}
