import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/roles/demo_seekers.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';
import 'package:homizi/features/seekers/seeker_score.dart';

void main() {
  test('roommate → roommate: the card and the preview share one scorer', () {
    final requirements = FinderRequirements.initial;
    for (final person in finderPeople) {
      final card = scoreFinderPerson(requirements, person);
      final preview = scoreFinderPerson(requirements, person);
      final api = scoreRoommate(requirements.toTraits(), person.traits);
      expect(card.percent, api.percent, reason: person.id);
      expect(preview.percent, card.percent, reason: person.id);
      if (card.percent != null) {
        expect(card.percent, inInclusiveRange(0, 100));
      }
    }
  });

  test('seeker → host: list row, preview and scoreSeeker agree', () {
    final property = sampleHostProperties.first;
    for (final match in demoSeekerPage().seekers) {
      final profile = profileFromMatch(match);
      final row = scoreSeekerForProperty(property: property, seeker: profile);
      final again = scoreSeekerForProperty(property: property, seeker: profile);
      final api = scoreSeeker(
        listingFromHostProperty(property),
        leadFromSeeker(profile),
      );
      expect(row.percent, api.percent, reason: profile.id);
      expect(again.percent, row.percent, reason: profile.id);
      expect(row.percent, inInclusiveRange(0, 100));
    }
  });
}
