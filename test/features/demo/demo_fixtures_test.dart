import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/interest/demo_tenants.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/demo_owner_gateway.dart';
import 'package:homizi/features/roles/demo_seekers.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';

void main() {
  test('demo people, seekers, and listings cover five Indian cities', () {
    const cities = {'Bengaluru', 'Pune', 'Mumbai', 'Ahmedabad', 'Delhi'};

    expect(demoTenantCards.length, greaterThanOrEqualTo(12));
    expect(
      demoTenantCards.map((card) => card.city).toSet(),
      containsAll(cities),
    );

    final seekers = demoSeekerPage().seekers;
    expect(seekers.length, greaterThanOrEqualTo(12));
    expect(
      seekers.map((seeker) => seeker.city).toSet(),
      containsAll(['Bengaluru', 'Pune', 'Mumbai', 'Ahmedabad', 'Delhi NCR']),
    );

    expect(demoRoommateSeekers.length, greaterThanOrEqualTo(12));
    expect(
      demoRoommateSeekers.map((seeker) => seeker.traits.city).toSet(),
      containsAll(['Bengaluru', 'Pune', 'Mumbai', 'Ahmedabad', 'Delhi NCR']),
    );

    final homes = demoOwnerSeed();
    expect(homes.length, greaterThanOrEqualTo(12));
    expect(homes.map((home) => home.draft.city).toSet(), containsAll(cities));

    expect(demoOwnerLeads().length, greaterThanOrEqualTo(12));

    final catalogCities = DemoCatalog.listings.map((home) => home.city).toSet();
    expect(
      catalogCities,
      containsAll(['Bengaluru', 'Pune', 'Mumbai', 'Ahmedabad', 'Delhi NCR']),
    );

    final sql = File('docs/staging_apply_DEMO_1021.sql').readAsStringSync();
    expect(sql, contains('qa+demo12@homizi.in'));
    expect(sql, contains("'Delhi'"));
    expect(sql.split('about_me').length, greaterThan(12));
  });
}
