import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/filter_screen.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/demo_owner_gateway.dart';
import 'package:homizi/features/owner/owner_dashboard_screen.dart';
import 'package:homizi/features/owner/owner_providers.dart';

void main() {
  testWidgets('the range keeps the minimum thumb at or below the maximum', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var start = InrRangeScale.presetMin;
    var end = InrRangeScale.presetMax;
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return HomiziRangeField(
                label: 'Budget',
                min: InrRangeScale.min,
                max: InrRangeScale.max,
                step: InrRangeScale.step,
                start: start,
                end: end,
                formatValue: formatInr,
                minSemantics: 'Budget minimum (INR)',
                maxSemantics: 'Budget maximum (INR)',
                sliderKey: const Key('budget-slider'),
                valueKey: const Key('budget-value'),
                onChanged: (nextStart, nextEnd) {
                  setState(() {
                    start = nextStart;
                    end = nextEnd;
                  });
                },
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(RangeSlider), findsOneWidget);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('₹12,000 – ₹35,000'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Budget minimum (INR), Budget maximum (INR)'),
      findsOneWidget,
    );
    expect(find.semantics.byValue(RegExp(r'Budget minimum \(INR\)')), findsOne);

    tester
        .widget<RangeSlider>(find.byKey(const Key('budget-slider')))
        .onChanged!(const RangeValues(90000, 18000));
    await tester.pump();

    expect(start <= end, isTrue);
    expect(start, 18000);
    expect(end, 90000);
    expect(find.text('₹18,000 – ₹90,000'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('budget-slider')),
      const Offset(48, 0),
    );
    await tester.pump();
    expect(start <= end, isTrue);
    expect(find.text('₹18,000 – ₹90,000'), findsNothing);
    semantics.dispose();
  });

  testWidgets('the filter sheet uses one rent range and saves both columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/filters',
          builder: (context, state) => const FilterScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    unawaited(router.push('/filters'));
    await tester.pumpAndSettle();

    expect(find.byType(Slider), findsNothing);
    expect(find.byType(RangeSlider), findsNWidgets(3));
    expect(
      tester.widget<Text>(find.byKey(const Key('filter-rent-value'))).data,
      'Any',
    );

    await tester.tap(find.text('Under ₹10,000'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      tester.widget<Text>(find.byKey(const Key('filter-rent-value'))).data,
      'Up to ₹9,999',
    );

    await tester.tap(find.text('₹20,000–₹35,000'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('filter-rent-value'))).data,
      '₹20,000 – ₹35,000',
    );

    tester
        .widget<RangeSlider>(find.byKey(const Key('filter-rent-slider')))
        .onChanged!(const RangeValues(35000, 12000));
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const Key('filter-rent-value'))).data,
      '₹12,000 – ₹35,000',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('filter-area-value'))).data,
      'Any',
    );

    await tester.ensureVisible(find.text('Show homes'));
    await tester.tap(find.text('Show homes'));
    await tester.pumpAndSettle();

    final saved = container.read(listingFilterProvider);
    expect(saved.budgetMinInr, 12000);
    expect(saved.budgetMaxInr, 35000);
    expect(saved.budgetMinInr! <= saved.budgetMaxInr!, isTrue);
  });

  testWidgets('owner tenant sheet filters people with the budget range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final memory = DemoListingMemory(seed: demoOwnerSeed());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              supabaseUrl: '',
              supabaseAnonKey: '',
              policyVersion: '2026-10-11-draft',
            ),
          ),
          ownerGatewayProvider.overrideWith((ref) => DemoOwnerGateway(memory)),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const OwnerDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('interested-demo-own-koramangala')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner-tenant-budget-slider')), findsOneWidget);
    expect(find.text('Meera K.'), findsOneWidget);
    expect(find.text('Arjun P.'), findsOneWidget);
    expect(find.text('Neha S.'), findsOneWidget);

    tester
        .widget<RangeSlider>(
          find.byKey(const Key('owner-tenant-budget-slider')),
        )
        .onChanged!(RangeValues(30000, InrRangeScale.max.toDouble()));
    await tester.pumpAndSettle();

    expect(find.text('₹30,000 and above'), findsOneWidget);
    expect(find.text('Meera K.'), findsNothing);
    expect(find.text('Neha S.'), findsNothing);
    expect(find.text('Arjun P.'), findsOneWidget);
  });
}
