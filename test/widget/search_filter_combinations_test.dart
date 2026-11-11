import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

Future<void> _openSearch(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(_ReadySession.new)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(
    find.descendant(
      of: find.byType(GlassyNavigationBar),
      matching: find.text('Search'),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a room-in-3BHK filter hides a whole 3 BHK', (tester) async {
    await _openSearch(tester);
    expect(
      find.byKey(const Key('listing-card-lst_koramangala')),
      findsOneWidget,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GlassyNavigationBar)),
    );
    container
        .read(listingFilterProvider.notifier)
        .replace(const ListingFilters(quickChip: 'room_in_3bhk'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('listing-card-lst_kharadi')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('listing-card-lst_baner')),
      400,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    expect(find.byKey(const Key('listing-card-lst_baner')), findsOneWidget);
    expect(
      find.byKey(const Key('listing-card-lst_ahd_bodakdev')),
      findsNothing,
    );
  });

  testWidgets(
    'combined Ahmedabad filters show one home and a clear empty state',
    (tester) async {
      await _openSearch(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GlassyNavigationBar)),
      );
      container
          .read(listingFilterProvider.notifier)
          .replace(
            const ListingFilters(
              city: 'Ahmedabad',
              locality: 'Bodakdev',
              quickChip: 'room_in_3bhk',
              friendlyTags: ['couple_friendly', 'lgbtq_friendly'],
              furnishing: 'furnished',
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.scrollUntilVisible(
        find.byKey(const Key('listing-card-lst_ahd_bodakdev_room')),
        400,
        scrollable: find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        ),
      );
      expect(
        find.byKey(const Key('listing-card-lst_ahd_bodakdev_room')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('listing-card-lst_ahd_bodakdev')),
        findsNothing,
      );
      expect(find.text('No homes match'), findsNothing);

      container
          .read(listingFilterProvider.notifier)
          .replace(
            const ListingFilters(
              city: 'Ahmedabad',
              quickChip: 'room_in_2bhk',
              friendlyTags: ['lgbtq_friendly'],
              budgetMaxInr: 1000,
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('No homes match'), findsOneWidget);
      expect(find.textContaining('Nothing matches'), findsOneWidget);
      expect(find.textContaining('Ahmedabad'), findsWidgets);
      expect(find.textContaining('LGBTQ+ friendly'), findsWidgets);
      expect(find.text('Clear filters'), findsOneWidget);
      expect(
        find.byKey(const Key('listing-card-lst_ahd_satellite_room')),
        findsNothing,
      );
    },
  );
}
