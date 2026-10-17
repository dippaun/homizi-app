import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/account/profile_records.dart';

void main() {
  test('profile writes omit contact and verification columns', () {
    final tenant = tenantProfileColumns(
      const TenantProfile(
        displayName: ' Ananya ',
        occupation: ' ',
        bio: 'Looking in Koramangala',
      ),
    );
    final host = hostProfileColumns(const HostProfile());
    expect(tenant.keys.toSet().intersection(forbiddenProfileColumns), isEmpty);
    expect(host.keys.toSet().intersection(forbiddenProfileColumns), isEmpty);
    expect(tenant['display_name'], 'Ananya');
    expect(tenant['occupation'], isNull);
    expect(host['company_name'], isNull);
    expect(host.containsKey('user_id'), isFalse);
    expect(
      hostProfileSaveError(const HostProfile(category: 'badge')),
      isNotNull,
    );
    expect(
      hostProfileSaveError(HostProfile(companyName: 'x' * 121)),
      isNotNull,
    );
    expect(hostProfileSaveError(const HostProfile()), isNull);
  });

  test('preference writes keep a blank row and reject an inverted budget', () {
    final blank = tenantPreferenceColumns(const TenantPreferences());
    expect(blank['budget_min_inr'], isNull);
    expect(blank['localities'], isEmpty);
    expect(blank['property_types'], <String>[]);
    expect(blank.keys, isNot(contains('email')));

    final saved = tenantPreferenceColumns(
      const TenantPreferences(
        budgetMinInr: 10000,
        budgetMaxInr: 25000,
        localities: ['Koramangala'],
        propertyTypes: ['apartment', 'not-a-type'],
        lifestyle: ['wfh'],
      ),
    );
    expect(saved['property_types'], <String>['apartment']);
    expect(saved['lifestyle'], <String>['wfh']);
    expect(
      preferencesFromRow({
        'budget_min_inr': 10000,
        'budget_max_inr': 25000,
        'localities': ['Koramangala'],
        'occupancy': 2,
        'property_types': ['apartment'],
        'lifestyle': <String>[],
      }).localities,
      ['Koramangala'],
    );
    expect(preferencesFromRow(null).isBlank, isTrue);
    expect(
      preferenceSaveError(
        const TenantPreferences(budgetMinInr: 40, budgetMaxInr: 10),
      ),
      isNotNull,
    );
  });
}
