import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staging_apply_next covers every migration after staging_apply', () {
    final apply = File('docs/staging_apply.sql').readAsStringSync();
    final next = File('docs/staging_apply_next.sql').readAsStringSync();
    final migrations =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    expect(migrations, isNotEmpty);
    expect(next, contains('on conflict (version) do update'));
    expect(next, contains('reset role'));
    expect(next, isNot(contains(r'\i ')));

    final pending = <String>[];
    for (final file in migrations) {
      final name = file.uri.pathSegments.last;
      final version = name.split('_').first;
      final body = file.readAsStringSync().trim();
      expect(body, isNotEmpty, reason: name);
      if (apply.contains(version)) {
        expect(
          next.contains(version),
          isFalse,
          reason: '$version is already in staging_apply.sql',
        );
        continue;
      }
      pending.add(version);
      expect(next.contains(version), isTrue, reason: name);
      expect(next.contains(body), isTrue, reason: '$name body missing');
      expect(
        next.contains("'$version'"),
        isTrue,
        reason: '$version was not recorded',
      );
    }

    expect(pending, [
      '20261016130000',
      '20261016140000',
      '20261016183000',
      '20261016190000',
    ]);
    expect(next, contains('drop policy if exists listing_photos_insert'));
    expect(next, contains('drop constraint if exists notifications_type'));
    expect(
      next,
      contains('create or replace function public.notify_on_interest'),
    );
    expect(next, contains('drop trigger if exists messages_reject_suspended'));
    expect(
      next,
      contains('create table if not exists public.analytics_events'),
    );
    expect(next, contains('follow-up migrations were not recorded'));
  });
}
