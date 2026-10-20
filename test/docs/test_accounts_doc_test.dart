import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the staging tester doc names the guardrails', () {
    final doc = File('docs/TEST_ACCOUNTS.md').readAsStringSync();
    expect(doc, contains('qa+'));
    expect(doc, contains('test1@homizi.in'));
    expect(doc, contains('test9999@homizi.in'));
    expect(doc, contains('docs/staging_apply_K_1019.sql'));
    expect(doc, contains('000000'));
    expect(doc, contains('staging_create_test_user'));
    expect(doc, contains('staging_purge_test_users'));
    expect(doc, contains('test_accounts_enabled'));
    expect(doc, contains('docs/staging_apply_M_1019.sql'));
    expect(doc, contains('docs/staging_apply_N_1020.sql'));
    expect(doc, contains('private.staging_secrets'));
    expect(doc, contains('on conflict (key) do nothing'));
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
    expect(migration, contains('^test[1-9][0-9]{0,3}@homizi\\.in\$'));
    expect(
      migration,
      isNot(contains("values ('test_accounts_enabled', true)")),
    );

    final sqlFiles = [
      ...Directory('supabase/migrations').listSync().whereType<File>(),
      ...Directory('docs').listSync().whereType<File>().where(
        (file) => file.path.contains('staging_apply'),
      ),
    ];
    for (final file in sqlFiles) {
      if (!file.path.endsWith('.sql')) {
        continue;
      }
      final sql = file.readAsStringSync();
      expect(
        sql,
        isNot(contains('REDACTED_STAGING_PASSWORD')),
        reason: file.path,
      );
      expect(
        sql,
        isNot(contains('insert into private.staging_secrets')),
        reason: file.path,
      );
    }
  });
}
