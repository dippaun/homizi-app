import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_swipe_card.dart';
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
  testWidgets('the search button opens the field and recent searches', (
    tester,
  ) async {
    await _openSearch(tester);

    expect(find.byType(SearchBar), findsNothing);
    expect(find.text('Recent searches'), findsNothing);
    expect(find.text('Search locality or home'), findsNothing);

    await tester.tap(find.byKey(const Key('explore-open-search')));
    await tester.pump();

    expect(find.byType(SearchBar), findsOneWidget);
    expect(find.text('Recent searches'), findsOneWidget);
    expect(
      find.byKey(const Key('recent-search-recent-koramangala')),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('the filter button opens one sheet with the existing filters', (
    tester,
  ) async {
    await _openSearch(tester);

    expect(find.byKey(const Key('explore-filter-sheet')), findsNothing);
    expect(find.byKey(const Key('quick-chip-1bhk')), findsNothing);

    await tester.tap(find.byKey(const Key('explore-open-filters')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explore-filter-sheet')), findsOneWidget);
    expect(find.byKey(const Key('quick-chip-1bhk')), findsOneWidget);
    expect(find.byKey(const Key('quick-chip-2bhk')), findsOneWidget);
    expect(find.byKey(const Key('quick-chip-room_in_2bhk')), findsOneWidget);
    await tester.tap(find.byKey(const Key('quick-chip-1bhk')));
    await tester.pump();

    final sheetScroll = find.descendant(
      of: find.byKey(const Key('explore-filter-sheet')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Newest'),
      120,
      scrollable: sheetScroll,
    );
    expect(find.text('Newest'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('explore-map-toggle')),
      120,
      scrollable: sheetScroll,
    );
    expect(find.byKey(const Key('explore-map-toggle')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('explore-set-priorities')),
      120,
      scrollable: sheetScroll,
    );
    expect(find.byKey(const Key('explore-set-priorities')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('filter-locality')),
      120,
      scrollable: sheetScroll,
    );
    expect(find.byKey(const Key('filter-locality')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('filter-rent-slider')),
      120,
      scrollable: sheetScroll,
    );
    expect(find.byKey(const Key('filter-rent-slider')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('filter-tag-couple_friendly')),
      120,
      scrollable: sheetScroll,
    );
    expect(find.byKey(const Key('filter-tag-couple_friendly')), findsOneWidget);
    expect(find.byKey(const Key('filter-tag-lgbtq_friendly')), findsOneWidget);
    expect(find.text('Furnished'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('filter-show-homes')),
      400,
      scrollable: sheetScroll,
    );
    await tester.tap(find.byKey(const Key('filter-show-homes')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('explore-filter-sheet')), findsNothing);
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('the shared card keeps one title line and four white chips', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 520,
            child: HomiziSwipeCard(
              title: 'Studio in Vastrapur with a very long name',
              verified: true,
              photo: ColoredBox(color: HomiziColors.ink),
              chips: [
                HomiziSwipeChip(label: '₹12,000/mo'),
                HomiziSwipeChip(label: 'Studio'),
                HomiziSwipeChip(label: 'Vastrapur'),
                HomiziSwipeChip(label: 'Furnished'),
                HomiziSwipeChip(label: 'Deposit ₹20,000'),
              ],
              badge: HomiziSwipeBadge(
                label: '40% match',
                background: HomiziColors.brandYellow,
                foreground: HomiziColors.white,
              ),
              actions: [
                HomiziSwipeAction(
                  tooltip: 'Skip',
                  icon: Icons.close,
                  onPressed: _noop,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(
      find.text('Studio in Vastrapur with a very long name'),
    );
    expect(title.maxLines, 1);
    expect(title.style?.color, HomiziColors.white);
    expect(find.text('₹12,000/mo'), findsOneWidget);
    expect(find.text('Furnished'), findsOneWidget);
    expect(find.text('Deposit ₹20,000'), findsNothing);
    final badge = tester.widget<Text>(find.text('40% match'));
    expect(badge.style?.color, HomiziColors.ink);
    expect(find.byTooltip('Skip'), findsOneWidget);
  });
}

void _noop() {}
