import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_date_field.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/listing_wizard_steps.dart';
import 'package:homizi/features/post_property/pg_listing.dart';
import 'package:homizi/features/post_property/post_property_choice.dart';

void main() {
  test('live rent cost uses Indian grouping and both totals', () {
    final cost = RentingCost.fromTexts(
      rent: '22000',
      deposit: '50,000',
      brokerage: '₹22000',
      oneTime: '1000',
      maintenance: '2000',
      electricity: '800',
      water: '200',
      wifi: '500',
      otherMonthly: '300',
    );
    expect(cost.rent, 22000);
    expect(cost.deposit, 50000);
    expect(cost.brokerage, 22000);
    expect(cost.moveInTotal, 73000);
    expect(cost.monthlyTotal, 25800);
    expect(formatInr(22000), '₹22,000');
    expect(formatInr(cost.moveInTotal), '₹73,000');
    expect(formatInr(cost.monthlyTotal), '₹25,800');
    expect(formatHomiziDay(DateTime(2026, 12)), '1 Dec 2026');
    expect(homiziDayIso('1 Dec 2026'), '2026-12-01');
    expect(homiziDayIso('1 December 2026'), '2026-12-01');
  });

  test('PG details round-trip in the existing feature JSON', () {
    const details = PgListingDetails(
      singlePrice: '9000',
      doublePrice: '7000',
      triplePrice: '6000',
      meals: true,
      gender: 'girls',
      curfew: '10:30 pm',
      rules: 'No loud music after 10.',
    );
    final again = PgListingDetails.decode(details.encode());
    expect(again.singlePrice, '9000');
    expect(again.meals, isTrue);
    expect(again.gender, 'girls');
    expect(PostPropertyChoice.values, contains(PostPropertyChoice.pg));
  });

  testWidgets('typing rent updates the live cost summary', (tester) async {
    final rent = TextEditingController();
    final deposit = TextEditingController();
    final brokerage = TextEditingController();
    final oneTime = TextEditingController();
    final maintenance = TextEditingController();
    final electricity = TextEditingController();
    final water = TextEditingController();
    final wifi = TextEditingController();
    final other = TextEditingController();
    addTearDown(() {
      rent.dispose();
      deposit.dispose();
      brokerage.dispose();
      oneTime.dispose();
      maintenance.dispose();
      electricity.dispose();
      water.dispose();
      wifi.dispose();
      other.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ChargesStep(
              draft: const ListingDraft(),
              rent: rent,
              deposit: deposit,
              brokerage: brokerage,
              oneTime: oneTime,
              maintenance: maintenance,
              electricity: electricity,
              water: water,
              wifi: wifi,
              other: other,
              brokerageTerms: TextEditingController(),
              showBroker: false,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('listing-rent')), '22000');
    await tester.enterText(find.byKey(const Key('listing-deposit')), '44000');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Calculating live'), findsOneWidget);
    expect(find.text('₹22,000'), findsWidgets);
    expect(find.text('₹44,000'), findsWidgets);
    expect(find.byKey(const Key('listing-cost-monthly')), findsOneWidget);
    expect(find.byKey(const Key('listing-cost-move-in')), findsOneWidget);
  });

  testWidgets('possession date opens a picker and shows 1 Dec 2026', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: HomiziDateField(
            fieldKey: const Key('listing-possession'),
            controller: controller,
            label: 'Possession date',
            initialWhenEmpty: DateTime(2026, 12),
            firstDate: DateTime(2026),
            lastDate: DateTime(2027),
          ),
        ),
      ),
    );
    final field = tester.widget<TextField>(
      find.byKey(const Key('listing-possession')),
    );
    expect(field.readOnly, isTrue);
    await tester.tap(find.byKey(const Key('listing-possession')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(controller.text, '1 Dec 2026');
  });

  testWidgets('dropdown menu stays a white surface with ink text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: DropdownButtonFormField<String>(
            initialValue: 'Student',
            items: const [
              DropdownMenuItem(value: 'Student', child: Text('Student')),
              DropdownMenuItem(value: 'Business', child: Text('Business')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(HomiziTheme.light().focusColor, HomiziColors.accentWash);
    final ring = HomiziTheme.light().filledButtonTheme.style!.side!.resolve({
      WidgetState.focused,
    });
    expect(ring?.color, HomiziColors.ink);
    expect(HomiziTheme.light().popupMenuTheme.color, HomiziColors.white);
    expect(
      HomiziTheme.light().popupMenuTheme.textStyle?.color,
      HomiziColors.ink,
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Business'), findsWidgets);
    expect(find.text('Other'), findsWidgets);
    final navyMenus = tester
        .widgetList<Material>(find.byType(Material))
        .where((material) => material.color == HomiziColors.ink);
    expect(navyMenus, isEmpty);
  });

  testWidgets('PG fields offer sharing, meals, and gender', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PgListingDetails? saved;
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PgListingFields(
              details: const PgListingDetails(),
              amenities: const [],
              onChanged: (details) => saved = details,
              onAmenity: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Beds & sharing'), findsOneWidget);
    expect(find.text('Single sharing (₹)'), findsOneWidget);
    expect(find.text('Meals included'), findsOneWidget);
    expect(find.text('Boys'), findsOneWidget);
    expect(find.text('Co-living'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('pg-single-price')), '9000');
    await tester.ensureVisible(find.byKey(const Key('pg-meals-yes')));
    await tester.tap(find.byKey(const Key('pg-meals-yes')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('pg-gender-boys')));
    await tester.tap(find.byKey(const Key('pg-gender-boys')));
    await tester.pump();
    expect(saved?.singlePrice, '9000');
    expect(saved?.meals, isTrue);
    expect(saved?.gender, 'boys');
  });
}
