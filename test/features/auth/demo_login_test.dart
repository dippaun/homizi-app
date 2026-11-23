import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/account/auth_contact.dart';
import 'package:homizi/features/auth/demo_login.dart';
import 'package:homizi/features/auth/demo_login_store.dart';

void main() {
  test('demo email and both phone shapes use code 123456', () {
    expect(isDemoLoginContact('demo@homizi.in'), isTrue);
    expect(isDemoLoginContact('  DEMO@homizi.in '), isTrue);
    expect(isDemoLoginContact('9979099873'), isTrue);
    expect(isDemoLoginContact('+919979099873'), isTrue);
    expect(isDemoLoginContact('919979099873'), isTrue);
    expect(isDemoLoginContact('test5@homizi.in'), isFalse);
    expect(isDemoLoginAttempt('9979099873', '123456'), isTrue);
    expect(isDemoLoginAttempt('demo@homizi.in', '000000'), isFalse);
  });

  test(
    'a new demo alias is a fresh qa mailbox and is not the typed address',
    () {
      final alias = newDemoAliasEmail(1732300000000);
      expect(alias, 'qa+d1732300000000@homizi.in');
      expect(isStagingFreshTesterEmail(alias), isTrue);
      expect(alias, isNot(demoLoginEmail));
      expect(newDemoUserId(42), 'demo-42');
    },
  );

  test('the saved demo profile round-trips without the code', () {
    const record = DemoLoginRecord(
      aliasEmail: 'qa+d1@homizi.in',
      userId: 'demo-1',
      displayName: 'Meera Shah',
      homiziWire: 'tenant',
    );
    final decoded = DemoLoginRecord.decode(record.encode());
    expect(decoded?.aliasEmail, record.aliasEmail);
    expect(decoded?.displayName, 'Meera Shah');
    expect(decoded?.homiziWire, 'tenant');
    expect(record.encode().contains('123456'), isFalse);
  });
}
