import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staging seed is a SQL-editor catalog without public contact', () {
    final text = File('docs/staging_seed.sql').readAsStringSync();
    expect(text, contains('c0ffee00-0000-4000-8000-000000000001'));
    expect(text, contains('Sunlit 2BHK in Koramangala'));
    expect('::public.property_type'.allMatches(text), hasLength(40));
    expect(text, contains("extensions.crypt(gen_random_uuid()::text"));
    expect(text, isNot(contains('local-dev-only')));
    expect(text, isNot(contains('+91')));
    expect(text, isNot(contains('address_line')));
    expect(text, isNot(contains('schema_migrations')));
    expect(text, isNot(contains(r'\i ')));
    expect(text, contains('staging seed expected 40 published listings'));
  });
}
