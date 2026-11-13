import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';
import 'package:homizi/features/seekers/seeker_score.dart';
import 'package:homizi/features/seekers/seeker_shortlist.dart';

void main() {
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

  test('seeker percent is scoreSeeker for this home', () {
    final seeker = demoSeekerProfiles['rohan-verma']!;
    final fit = scoreSeekerForProperty(property: property, seeker: seeker);
    final direct = scoreSeeker(
      listingFromHostProperty(property),
      leadFromSeeker(seeker),
    );
    expect(fit.percent, direct.percent);
    expect(fit.topReasons, direct.topReasons);
    expect(fit.missing, direct.missing);
    expect(fit.percent, inInclusiveRange(0, 100));
    expect(savedHostPriorities(const HostPriorities()), isNull);
  });

  test('saved host priorities and a must-have filter the score', () {
    final seeker = demoSeekerProfiles['aditi-mehta']!;
    const saved = HostPriorities(
      order: [
        HostFactorId.pets,
        HostFactorId.furnishing,
        HostFactorId.nonSmoker,
        HostFactorId.workingProfessional,
        HostFactorId.nonDrinker,
        HostFactorId.clean,
        HostFactorId.gender,
        HostFactorId.longStay,
      ],
      mustHave: {HostFactorId.nonSmoker},
    );
    final fit = scoreSeekerForProperty(
      property: property,
      seeker: seeker,
      priorities: saved,
    );
    final direct = scoreSeeker(
      listingFromHostProperty(property),
      leadFromSeeker(seeker),
      priorities: saved,
    );
    expect(savedHostPriorities(saved), isNotNull);
    expect(fit.percent, direct.percent);
    expect(seekerBlockedByHardFilter(saved, fit), isFalse);

    const smoker = SeekerPublicProfile(
      id: 'smoker-demo',
      name: 'Asha Rao',
      city: 'Ahmedabad',
      localities: ['Vastrapur'],
      budgetMinInr: 15000,
      budgetMaxInr: 26000,
      roomType: '2bhk',
      furnishing: 'furnished',
      amenities: [],
      seekerKind: 'tenant',
      about: 'I smoke on the balcony.',
      profession: 'working',
      smokes: true,
      lifestyleKnown: true,
    );
    final blocked = scoreSeekerForProperty(
      property: property,
      seeker: smoker,
      priorities: saved,
    );
    expect(blocked.missing, contains('Smokes'));
    expect(seekerBlockedByHardFilter(saved, blocked), isTrue);
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
