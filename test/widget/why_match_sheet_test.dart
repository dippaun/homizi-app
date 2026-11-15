import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';

void main() {
  testWidgets('Why this match lists each factor, its points, and the time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final now = DateTime(2026, 11, 14, 18);
    final report = scoreMatch(
      seeker: const SeekerMatchInput(
        budgetMinInr: 10000,
        budgetMaxInr: 18000,
        officeLatitude: 23.04977,
        officeLongitude: 72.511,
        officeLabel: 'Prahlad Nagar',
        smoking: 'never',
        food: 'veg',
      ),
      subject: const MatchSubject(
        rentInr: 15000,
        latitude: 23.012,
        longitude: 72.511,
        smoking: 'never',
        food: 'non_veg',
      ),
      computedAt: now.subtract(const Duration(minutes: 5)),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: MatchBreakdownSheet(
            match: listingMatchFromReport(report),
            now: now,
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('why-match-title')), findsOneWidget);
    expect(find.text('Why this match'), findsOneWidget);
    expect(find.text('Updated 5 min ago'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Budget ₹15k fits your ₹10k–₹18k'), findsOneWidget);
    expect(find.text('25/25'), findsWidgets);
    expect(find.text('Commute'), findsOneWidget);
    expect(find.textContaining('Prahlad Nagar'), findsWidgets);
    expect(find.text('Non-smoker matches'), findsOneWidget);
    expect(find.text('10/10'), findsWidgets);
    expect(find.text('Food preference does not match.'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsWidgets);
    expect(find.byIcon(Icons.close), findsWidgets);
    expect(find.text('Preferences used'), findsOneWidget);
    expect(find.text('Budget: ₹10,000–₹18,000'), findsOneWidget);
    expect(find.text('Work: Prahlad Nagar'), findsOneWidget);
    expect(find.text('Food: Veg'), findsOneWidget);
    expect(find.text('Edit preferences'), findsOneWidget);

    final budget = tester.widget<Text>(find.text('25/25').first);
    expect(budget.style?.color, HomiziColors.success);
    final food = tester.widget<Text>(find.text('0/8'));
    expect(food.style?.color, HomiziColors.error);
    expect(find.text('Why this match'), findsOneWidget);
  });

  testWidgets('a partial factor is amber, not a full match', (tester) async {
    const match = ListingMatch(
      score: 4,
      factors: [
        MatchFactor(
          label: 'Food',
          matched: false,
          detail: 'Veg is close to eggetarian.',
          points: 4,
          maxPoints: 8,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: const Scaffold(body: MatchBreakdownSheet(match: match)),
      ),
    );
    expect(find.byIcon(Icons.remove), findsOneWidget);
    final points = tester.widget<Text>(find.text('4/8'));
    expect(points.style?.color, HomiziColors.warning);
    final icon = tester.widget<Icon>(find.byIcon(Icons.remove));
    expect(icon.color, HomiziColors.warning);
  });
}
