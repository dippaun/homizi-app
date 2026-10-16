import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/analytics/analytics_gateway.dart';
import 'package:homizi/features/analytics/demo_analytics_gateway.dart';
import 'package:homizi/features/analytics/domain/analytics_event.dart';

void main() {
  test('event names match the migration check', () {
    final sql = File(
      'supabase/migrations/20261016183000_realtime_moderation_analytics.sql',
    ).readAsStringSync();
    for (final name in analyticsEventNames) {
      expect(sql, contains("'$name'"));
    }
  });

  test('properties keep only listing and match uuids', () {
    const listing = '12121212-1212-4121-8121-121212121212';
    final clean = sanitizeAnalyticsProperties({
      'listing_id': listing,
      'match_id': 'not-a-uuid',
      'phone': '+910000000001',
      'email': 'ada@example.test',
      'name': 'Ananya',
      'body': 'call 9876543210',
    });
    expect(clean, {'listing_id': listing});
    expect(clean.values.join(), isNot(contains('@')));
    expect(clean.values.join(), isNot(contains('9876543210')));
  });

  test('opt-out and unknown names are not stored', () {
    expect(
      analyticsWrite(
        optedOut: true,
        userId: 'user-1',
        name: 'app_open',
        properties: const {},
      ),
      isNull,
    );
    expect(
      analyticsWrite(
        optedOut: false,
        userId: 'user-1',
        name: 'screen_view',
        properties: const {},
      ),
      isNull,
    );
    expect(
      analyticsWrite(
        optedOut: false,
        userId: null,
        name: 'app_open',
        properties: const {},
      ),
      isNull,
    );
    final write = analyticsWrite(
      optedOut: false,
      userId: 'user-1',
      name: 'listing_view',
      properties: const {'email': 'ada@example.test'},
    );
    expect(write?['name'], 'listing_view');
    expect(write?['properties'], isEmpty);
  });

  test('the demo gateway respects opt-out', () async {
    var optedOut = false;
    final gateway = DemoAnalyticsGateway(optedOut: () => optedOut);
    await gateway.log('app_open');
    optedOut = true;
    await gateway.log('message_sent', properties: {'phone': '+910000000001'});
    expect(gateway.events, hasLength(1));
    expect(gateway.events.single['name'], 'app_open');
    expect(gateway, isA<AnalyticsGateway>());
  });
}
