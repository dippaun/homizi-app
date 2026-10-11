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
  });
}
