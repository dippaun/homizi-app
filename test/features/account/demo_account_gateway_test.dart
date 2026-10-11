import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/session/session_state.dart';

void main() {
  test(
    'demo profiles stay in memory and verification stays mock pending',
    () async {
      final gateway = DemoAccountGateway();
      expect(await gateway.restore(policyVersion: '2026-10-11-draft'), isNull);

      await gateway.saveTenantProfile(
        const TenantProfile(displayName: 'Ananya', occupation: 'Designer'),
      );
      await gateway.saveHostProfile(
        const HostProfile(category: 'flatmate', companyName: 'Demo'),
      );
      final status = await gateway.requestMockVerification();

      expect((await gateway.loadTenantProfile()).displayName, 'Ananya');
      expect(status, VerificationStatus.mockPending);
      expect((await gateway.loadTenantProfile()).verification, status);
      expect((await gateway.loadHostProfile()).category, 'flatmate');

      final contact = parseAuthContact('ananya@example.test')!;
      final session = await gateway.signInDev(
        contact: contact,
        policyVersion: '2026-10-11-draft',
      );
      expect(session.userId, isNull);
      expect(session.role, isNull);
      await gateway.setRole(AccountRole.both);
      expect(
        (await gateway.signInDev(
          contact: contact,
          policyVersion: '2026-10-11-draft',
        )).role,
        AccountRole.both,
      );

      final deleted = await gateway.deleteAccount();
      expect(deleted, contains('Deleted on this device'));
      expect(deleted.contains('@'), isFalse);
      expect((await gateway.loadTenantProfile()).displayName, isEmpty);
      expect((await gateway.loadHostProfile()).companyName, isEmpty);
    },
  );
}
