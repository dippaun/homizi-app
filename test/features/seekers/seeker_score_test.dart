import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/roles/requirement_match.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';
import 'package:homizi/features/seekers/seeker_score.dart';
import 'package:homizi/features/seekers/seeker_shortlist.dart';

void main() {
  test('seeker percent is the existing property matcher', () {
    const property = HostProperty(
      id: 'vastrapur',
      label: '2 BHK · Vastrapur',
      city: 'Ahmedabad',
      locality: 'Vastrapur',
      rentInr: 22000,
      propertyType: 'apartment',
      furnishing: 'furnished',
      amenities: [],
    );
    final seeker = demoSeekerProfiles['rohan-verma']!;
    final fit = scoreSeekerForProperty(property: property, seeker: seeker);
    final expected = requirementListingMatch(
      listingCity: property.city,
      listingLocality: property.locality,
      rentInr: property.rentInr,
      propertyType: property.propertyType,
      furnishing: property.furnishing,
      listingAmenities: property.amenities,
      requirementCity: seeker.city,
      requirementLocalities: seeker.localities,
      budgetMinInr: seeker.budgetMinInr,
      budgetMaxInr: seeker.budgetMaxInr,
      roomTypes: [seeker.roomType],
      propertyTypes: const ['apartment'],
      requirementFurnishings: [seeker.furnishing],
      requirementAmenities: seeker.amenities,
    );
    expect(fit.percent, expected);
    expect(fit.percent, isNot(96));
    expect(fit.topReasons, contains('Location Matches'));
    expect(fit.topReasons, contains('Property Type Matches'));
    expect(fit.missing, contains('Budget does not cover this rent'));
    expect(fit.topReasons, isNot(contains('Budget Matches')));
  });

  test('profiles carry no private verification data', () {
    for (final profile in demoSeekerProfiles.values) {
      final blob = [
        profile.name,
        profile.about,
        profile.education,
        profile.hometown,
        profile.occupation,
        ...profile.languages,
        ...profile.lifestyle,
        ...profile.houseRules,
      ].join(' ').toLowerCase();
      expect(blob.contains('aadhaar'), isFalse);
      expect(blob.contains('@'), isFalse);
      expect(blob.contains('+91'), isFalse);
      expect(profile.userId, isEmpty);
    }
  });

  test('shortlist survives a new controller', () async {
    final store = MemorySeekerDeckStore();
    final first = ProviderContainer(
      overrides: [seekerDeckStoreProvider.overrideWithValue(store)],
    );
    addTearDown(first.dispose);
    first.read(seekerDeckProvider.notifier).toggleShortlist('rohan-verma');
    await first.read(seekerDeckProvider.notifier).persistence;
    expect(first.read(seekerDeckProvider).shortlisted, contains('rohan-verma'));

    final second = ProviderContainer(
      overrides: [seekerDeckStoreProvider.overrideWithValue(store)],
    );
    addTearDown(second.dispose);
    await second.read(seekerDeckProvider.notifier).persistence;
    expect(
      second.read(seekerDeckProvider).shortlisted,
      contains('rohan-verma'),
    );
  });
}
