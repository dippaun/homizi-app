import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('staging_apply_next covers every migration after staging_apply', () {
    final apply = File('docs/staging_apply.sql').readAsStringSync();
    final next = File('docs/staging_apply_next.sql').readAsStringSync();
    final later = File('docs/staging_apply_C_1017.sql').readAsStringSync();
    final listings = File('docs/staging_apply_B_1017.sql').readAsStringSync();
    final owners = File('docs/staging_apply_B_1017b.sql').readAsStringSync();
    final tools = File('docs/staging_apply_C_1017b.sql').readAsStringSync();
    final search = File('docs/staging_apply_A_1017b.sql').readAsStringSync();
    final migrations =
        Directory('supabase/migrations')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.sql'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    expect(migrations, isNotEmpty);
    expect(next, contains('on conflict (version) do update'));
    expect(later, contains('on conflict (version) do update'));
    expect(listings, contains('on conflict (version) do update'));
    expect(owners, contains('on conflict (version) do update'));
    expect(search, contains('on conflict (version) do update'));
    expect(search, isNot(contains(r'\i ')));
    expect(next, contains('reset role'));
    expect(next, isNot(contains(r'\i ')));
    expect(later, isNot(contains(r'\i ')));
    expect(listings, isNot(contains(r'\i ')));
    expect(owners, isNot(contains(r'\i ')));
    expect(tools, contains('on conflict (version) do update'));
    expect(tools, isNot(contains(r'\i ')));
    expect(tools, contains('notification_preferences'));
    expect(tools, contains('inventory-photos'));

    final pending = <String>[];
    final account = <String>[];
    final discovery = <String>[];
    final owner = <String>[];
    final sliceC = <String>[];
    final explore = <String>[];
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
      if (next.contains(version)) {
        pending.add(version);
        expect(next.contains(body), isTrue, reason: '$name body missing');
        expect(
          next.contains("'$version'"),
          isTrue,
          reason: '$version was not recorded',
        );
        continue;
      }
      if (version.startsWith('2026101715')) {
        explore.add(version);
        expect(search.contains(version), isTrue, reason: name);
        expect(search.contains(body), isTrue, reason: '$name body missing');
        expect(
          search.contains("'$version'"),
          isTrue,
          reason: '$version was not recorded',
        );
        continue;
      }
      if (version.startsWith('2026101717')) {
        sliceC.add(version);
        expect(tools.contains(version), isTrue, reason: name);
        expect(tools.contains(body), isTrue, reason: '$name body missing');
        expect(
          tools.contains("'$version'"),
          isTrue,
          reason: '$version was not recorded',
        );
        continue;
      }
      if (version == '20261017130000') {
        discovery.add(version);
        expect(listings.contains(version), isTrue, reason: name);
        expect(listings.contains(body), isTrue, reason: '$name body missing');
        expect(
          listings.contains("'$version'"),
          isTrue,
          reason: '$version was not recorded',
        );
        continue;
      }
      if (version.startsWith('2026101716')) {
        owner.add(version);
        expect(owners.contains(version), isTrue, reason: name);
        expect(owners.contains(body), isTrue, reason: '$name body missing');
        expect(
          owners.contains("'$version'"),
          isTrue,
          reason: '$version was not recorded',
        );
        continue;
      }
      account.add(version);
      expect(later.contains(version), isTrue, reason: name);
      expect(later.contains(body), isTrue, reason: '$name body missing');
      expect(
        later.contains("'$version'"),
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
    expect(account, ['20261017120000']);
    expect(discovery, ['20261017130000']);
    expect(owner, ['20261017160000', '20261017160100']);
    expect(owners, contains('get_my_listing_stats'));
    expect(owners, contains('user_badges'));
    expect(owners, contains('listing_views'));
    expect(sliceC, ['20261017170000']);
    expect(explore, ['20261017150000']);
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
