import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the staging tester doc names the guardrails', () {
    final doc = File('docs/TEST_ACCOUNTS.md').readAsStringSync();
    expect(doc, contains('qa+'));
    expect(doc, contains('000000'));
    expect(doc, contains('staging_create_test_user'));
    expect(doc, contains('staging_purge_test_users'));
    expect(doc, contains('test_accounts_enabled'));
    expect(doc, contains('docs/staging_apply_M_1019.sql'));
    expect(doc, contains('50'));
    expect(doc.toLowerCase(), contains('production'));
    expect(doc, contains('role picker'));
    expect(doc, contains('REDACTED_STAGING_PASSWORD'));
    expect(doc.toLowerCase(), contains('service role'));

    final apply = File('docs/staging_apply_M_1019.sql').readAsStringSync();
    expect(apply, contains("values ('test_accounts_enabled', true)"));
    expect(apply, contains('staging_create_test_user'));
    expect(apply, contains('staging_purge_test_users'));

    final migration = File(
      'supabase/migrations/20261019101900_staging_test_accounts.sql',
    ).readAsStringSync();
    expect(migration, contains('staging_create_test_user'));
    expect(
      migration,
      isNot(contains("values ('test_accounts_enabled', true)")),
    );
  });
}
