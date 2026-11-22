import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart'
    hide matchWeightBudget, matchWeightFood, matchWeightMoveIn, matchWeightPets;
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';

void main() {
  final clock = DateTime.utc(2026, 11, 14, 12);

  test('weights add up to 100', () {
    expect(
      matchWeightBudget +
          matchWeightCommute +
          matchWeightOccupancy +
          matchWeightPropertyType +
          matchWeightSmoking +
          matchWeightFood +
          matchWeightMoveIn +
          matchWeightPets +
          matchWeightGender +
          matchWeightSchedule,
      100,
    );
  });

  test('the same inputs always return the same score', () {
    final seeker = _seeker();
    final subject = _home();
    final first = scoreMatch(
      seeker: seeker,
      subject: subject,
      computedAt: clock,
    );
    final second = scoreMatch(
      seeker: seeker,
      subject: subject,
      computedAt: clock.add(const Duration(minutes: 5)),
    );
    expect(second.total, first.total);
    expect(
      second.factors.map((factor) => factor.points).toList(),
      first.factors.map((factor) => factor.points).toList(),
    );
    expect(
      first.factors.fold<int>(0, (sum, factor) => sum + factor.points),
      first.total,
    );
    expect(second.preferencesUsed, first.preferencesUsed);
  });

  test('preference lines name every factor, including ones left unset', () {
    final lines = seekerPreferenceLines(
      const SeekerMatchInput(
        budgetMinInr: 12000,
        budgetMaxInr: 18000,
        city: 'Pune',
        localities: ['Kothrud'],
        officeLabel: 'Koregaon Park',
        occupancy: 'shared',
        food: 'veg',
      ),
    );
    expect(lines, [
      'Budget: ₹12,000–₹18,000',
      'Location: Pune, Kothrud',
      'Work: Koregaon Park',
      'Occupancy: Shared occupancy',
      'Property type: not set',
      'Move-in: not set',
      'Food: Veg',
      'Smoking: not set',
      'Pets: not set',
      'Gender: not set',
      'Schedule: not set',
    ]);
    final report = scoreMatch(
      seeker: const SeekerMatchInput(food: 'veg'),
      subject: const MatchSubject(food: 'eggetarian'),
      computedAt: clock,
    );
    final food = report.factor(MatchFactorId.food)!;
    expect(food.points, matchWeightFoodClose);
    expect(food.matched, isFalse);
    final card = listingMatchFromReport(report);
    expect(card.preferencesUsed, report.preferencesUsed);
    expect(card.factors.first.maxPoints, isNotNull);
    expect(card.factors.first.mark, MatchMark.full);
    expect(
      card.factors.firstWhere((factor) => factor.label == 'Food').mark,
      MatchMark.partial,
    );
  });

  test('a blank seeker hides the score', () {
    final report = scoreMatch(
      seeker: const SeekerMatchInput(),
      subject: _home(),
      computedAt: clock,
    );
    expect(report.visible, isFalse);
    expect(report.total, 0);
    expect(report.factors, isEmpty);
    expect(listingMatchFromReport(report).showBadge, isFalse);
  });

  test('budget, a short commute, and a non-smoker add their weights', () {
    final report = scoreMatch(
      seeker: const SeekerMatchInput(
        budgetMinInr: 10000,
        budgetMaxInr: 18000,
        officeLatitude: 23.04977,
        officeLongitude: 72.511,
        officeLabel: 'Prahlad Nagar',
        smoking: 'never',
      ),
      subject: const MatchSubject(
        rentInr: 15000,
        latitude: 23.012,
        longitude: 72.511,
        smoking: 'never',
      ),
      computedAt: clock,
    );
    final budget = report.factor(MatchFactorId.budget)!;
    final commute = report.factor(MatchFactorId.commute)!;
    final smoking = report.factor(MatchFactorId.smoking)!;
    expect(budget.points, matchWeightBudget);
    expect(budget.matched, isTrue);
    expect(budget.detail, 'Budget ₹15k fits your ₹10k–₹18k');
    expect(budget.line, 'Budget ₹15k fits your ₹10k–₹18k ✓ +25');
    expect(commute.points, matchWeightCommute);
    expect(commute.detail, contains('4.2 km'));
    expect(commute.detail, contains('Prahlad Nagar'));
    expect(smoking.points, matchWeightSmoking);
    expect(smoking.detail, 'Non-smoker matches');
    expect(report.total, greaterThanOrEqualTo(25 + 15 + 10));
  });

  test('each factor scores a hit, a near miss, and a miss', () {
    final inside = _score(_seeker(), _home());
    expect(inside.factor(MatchFactorId.budget)!.points, matchWeightBudget);
    expect(inside.factor(MatchFactorId.propertyType)!.matched, isTrue);
    expect(inside.factor(MatchFactorId.occupancy)!.detail, contains('Entire'));
    expect(inside.factor(MatchFactorId.food)!.points, matchWeightFood);
    expect(inside.factor(MatchFactorId.pets)!.points, matchWeightPets);
    expect(inside.factor(MatchFactorId.gender)!.points, matchWeightGender);
    expect(inside.factor(MatchFactorId.moveIn)!.points, matchWeightMoveIn);
    expect(inside.factor(MatchFactorId.schedule)!.points, matchWeightSchedule);

    final near = _score(
      _seeker(budgetMin: 10000, budgetMax: 12000),
      _home(rent: 13500),
    );
    expect(near.factor(MatchFactorId.budget)!.points, matchWeightBudgetNear);
    expect(near.factor(MatchFactorId.budget)!.matched, isFalse);

    final outside = _score(
      _seeker(budgetMin: 10000, budgetMax: 12000),
      _home(rent: 40000),
    );
    expect(outside.factor(MatchFactorId.budget)!.points, 0);

    final swapped = _score(_seeker(budgetMax: 10000), _home(rent: 15000));
    expect(swapped.factor(MatchFactorId.budget)!.points, matchWeightBudget);

    expect(
      _score(
        _seeker(),
        _home(lat: 28.6, lng: 77.2),
      ).factor(MatchFactorId.commute)!.points,
      0,
    );
    expect(
      _score(
        _seeker(officeLat: null),
        _home(),
      ).factor(MatchFactorId.commute)!.points,
      matchWeightCommute,
    );
    expect(
      _score(
        const SeekerMatchInput(city: 'Mumbai'),
        _home(),
      ).factor(MatchFactorId.commute)!.points,
      matchWeightCommuteOtherCity,
    );
    expect(
      _score(
        const SeekerMatchInput(city: 'Bengaluru', localities: ['Indiranagar']),
        _home(),
      ).factor(MatchFactorId.commute)!.points,
      matchWeightCommute15Km,
    );

    expect(
      _score(
        _seeker(occupancy: 'shared'),
        _home(),
      ).factor(MatchFactorId.occupancy)!.points,
      0,
    );
    expect(
      _score(
        _seeker(occupancy: 'shared'),
        _home(type: 'shared_room'),
      ).factor(MatchFactorId.occupancy)!.points,
      matchWeightOccupancy,
    );
    expect(
      _score(
        _seeker(types: const ['pg']),
        _home(type: 'pg'),
      ).factor(MatchFactorId.propertyType)!.points,
      matchWeightPropertyType,
    );
    expect(
      _score(
        _seeker(types: const ['1rk']),
        _home(type: 'studio', bedrooms: 0),
      ).factor(MatchFactorId.propertyType)!.points,
      matchWeightPropertyType,
    );
    expect(
      _score(
        _seeker(types: const ['villa']),
        _home(),
      ).factor(MatchFactorId.propertyType)!.points,
      0,
    );

    expect(
      _score(
        _seeker(),
        _home(smoking: 'regularly'),
      ).factor(MatchFactorId.smoking)!.points,
      0,
    );
    expect(
      _score(_seeker(food: 'veg'), _home()).factor(MatchFactorId.food)!.points,
      0,
    );
    expect(
      _score(
        _seeker(food: 'veg'),
        _home(food: 'eggetarian'),
      ).factor(MatchFactorId.food)!.points,
      matchWeightFoodClose,
    );
    expect(
      _score(
        _seeker(pets: 'avoid'),
        _home(),
      ).factor(MatchFactorId.pets)!.points,
      0,
    );
    expect(
      _score(
        _seeker(gender: 'female'),
        _home(genders: const ['bachelors']),
      ).factor(MatchFactorId.gender)!.points,
      0,
    );
    expect(
      _score(
        _seeker(schedule: 'early'),
        _home(schedule: 'night'),
      ).factor(MatchFactorId.schedule)!.points,
      0,
    );
    expect(
      _score(
        _seeker(schedule: 'early'),
        _home(),
      ).factor(MatchFactorId.schedule)!.points,
      matchWeightScheduleClose,
    );
    expect(
      _score(
        _seeker(),
        _home(available: DateTime(2027, 3)),
      ).factor(MatchFactorId.moveIn)!.points,
      0,
    );
  });

  test('two people score on overlapping budgets and habits', () {
    final report = scoreMatch(
      seeker: SeekerMatchInput(
        budgetMinInr: 8000,
        budgetMaxInr: 15000,
        city: 'Ahmedabad',
        localities: const ['Satellite'],
        smoking: 'never',
        food: 'veg',
        moveIn: DateTime.utc(2026, 11, 20),
      ),
      subject: MatchSubject(
        budgetMinInr: 9000,
        budgetMaxInr: 14000,
        city: 'Ahmedabad',
        locality: 'Prahlad Nagar',
        smoking: 'sometimes',
        food: 'non_veg',
        availableOn: DateTime.utc(2026, 12, 20),
      ),
      computedAt: clock,
    );
    expect(report.factor(MatchFactorId.budget)!.points, matchWeightBudget);
    expect(
      report.factor(MatchFactorId.commute)!.points,
      matchWeightCommute15Km,
    );
    expect(report.factor(MatchFactorId.smoking)!.points, 0);
    expect(report.factor(MatchFactorId.food)!.points, 0);
    expect(report.total, lessThan(100));
  });

  test('freshness reads just now and minutes ago', () {
    final now = DateTime(2026, 11, 14, 15, 30);
    expect(matchUpdatedLabel(now, now), 'Updated just now');
    expect(
      matchUpdatedLabel(now.subtract(const Duration(seconds: 20)), now),
      'Updated just now',
    );
    expect(
      matchUpdatedLabel(now.subtract(const Duration(minutes: 5)), now),
      'Updated 5 min ago',
    );
    expect(
      matchUpdatedLabel(now.subtract(const Duration(minutes: 1)), now),
      'Updated 1 min ago',
    );
  });

  test('the demo requirement scores Koramangala through the engine', () {
    final listing = DemoCatalog.listings.firstWhere(
      (home) => home.id == 'lst_koramangala',
    );
    final report = scoreMatch(
      seeker: seekerFromRequirement(demoTenantRequirement),
      subject: matchSubjectFromListing(listing),
      computedAt: clock,
    );
    expect(report.total, 100);
    expect(report.factors.every((factor) => factor.matched), isTrue);
    final card = listingMatchFromReport(report);
    expect(card.score, 100);
    expect(card.showBadge, isTrue);
    expect(
      card.factors.fold<int>(0, (sum, factor) => sum + factor.points),
      card.score,
    );
  });
}

MatchReport _score(SeekerMatchInput seeker, MatchSubject subject) {
  return scoreMatch(
    seeker: seeker,
    subject: subject,
    computedAt: DateTime.utc(2026, 11, 14),
  );
}

SeekerMatchInput _seeker({
  int budgetMin = 18000,
  int budgetMax = 28000,
  String occupancy = 'entire',
  List<String> types = const ['apartment'],
  String smoking = 'never',
  String food = 'non_veg',
  String pets = 'required',
  String gender = 'family',
  String schedule = 'flexible',
  double? officeLat = 12.935,
}) {
  return SeekerMatchInput(
    budgetMinInr: budgetMin,
    budgetMaxInr: budgetMax,
    occupancy: occupancy,
    propertyTypes: types,
    city: 'Bengaluru',
    localities: const ['Koramangala'],
    officeLatitude: officeLat,
    officeLongitude: officeLat == null ? null : 77.624,
    officeLabel: 'Koramangala office',
    moveIn: DateTime(2026, 11, 20),
    smoking: smoking,
    food: food,
    pets: pets,
    gender: gender,
    schedule: schedule,
  );
}

MatchSubject _home({
  int rent = 22000,
  String type = 'apartment',
  int bedrooms = 2,
  double lat = 12.935,
  double lng = 77.624,
  String smoking = 'never',
  String food = 'non_veg',
  String pets = 'allowed',
  List<String> genders = const ['family'],
  String schedule = 'flexible',
  DateTime? available,
}) {
  return MatchSubject(
    rentInr: rent,
    propertyType: type,
    bedrooms: bedrooms,
    city: 'Bengaluru',
    locality: 'Koramangala',
    latitude: lat,
    longitude: lng,
    availableOn: available ?? DateTime(2026, 11),
    smoking: smoking,
    food: food,
    pets: pets,
    acceptedGenders: genders,
    schedule: schedule,
  );
}
