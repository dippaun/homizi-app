import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'the staging define writer refuses the placeholder and hides the value',
    () async {
      final missing = await Process.run(
        'python3',
        ['tool/staging_build_defines.py', '/tmp/homizi-should-not-write.json'],
        environment: {...Platform.environment, 'STAGING_TEST_PASSWORD': ''},
      );
      expect(missing.exitCode, 1);
      expect(missing.stdout, isNot(contains('staging-fixture-password')));

      final placeholder = await Process.run(
        'python3',
        ['tool/staging_build_defines.py', '/tmp/homizi-should-not-write.json'],
        environment: {
          ...Platform.environment,
          'STAGING_TEST_PASSWORD': 'REDACTED_STAGING_PASSWORD',
        },
      );
      expect(placeholder.exitCode, 1);
      expect(File('/tmp/homizi-should-not-write.json').existsSync(), isFalse);

      const fixture = 'staging-fixture-password';
      final out = File(
        '${Directory.systemTemp.path}/homizi-staging-defines-test.json',
      );
      if (out.existsSync()) {
        out.deleteSync();
      }
      final written = await Process.run(
        'python3',
        ['tool/staging_build_defines.py', out.path],
        environment: {
          ...Platform.environment,
          'STAGING_TEST_PASSWORD': fixture,
        },
      );
      expect(written.exitCode, 0, reason: '${written.stderr}');
      expect('${written.stdout}${written.stderr}', isNot(contains(fixture)));
      final json = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
      expect(json['STAGING_TEST_PASSWORD'], fixture);
      expect(json['APP_ENV'], 'staging');
      final committed =
          jsonDecode(File('config/staging.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(committed['STAGING_TEST_PASSWORD'], 'REDACTED_STAGING_PASSWORD');
      out.deleteSync();
    },
  );
}
