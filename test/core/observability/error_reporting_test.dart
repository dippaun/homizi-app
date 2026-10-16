import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/observability/error_reporting.dart';

void main() {
  test('error reporting stays off unless a DSN is compiled in', () async {
    final off = AppConfig.parse(
      rawEnvironment: 'staging',
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'sb_publishable_example',
      policyVersion: '2026-10-11-draft',
    );
    expect(off.reportsErrors, isFalse);
    expect(off.sentryDsn, isEmpty);

    final on = AppConfig.parse(
      rawEnvironment: 'staging',
      supabaseUrl: 'https://example.supabase.co',
      supabaseAnonKey: 'sb_publishable_example',
      policyVersion: '2026-10-11-draft',
      sentryDsn: ' https://example.invalid/project ',
    );
    expect(on.reportsErrors, isTrue);
    expect(on.sentryDsn, 'https://example.invalid/project');

    var ran = false;
    await startHomizi(off, () async {
      ran = true;
    });
    expect(ran, isTrue);
  });
}
