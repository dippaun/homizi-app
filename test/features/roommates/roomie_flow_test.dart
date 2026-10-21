import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/roommates/roomie/roomie.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';

void main() {
  testWidgets('preferences, a mutual match, chat, and exploring flats together', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    expect(roomiePeople.length, greaterThanOrEqualTo(12));
    expect(
      roomiePeople.map((person) => person.brief.city).toSet(),
      containsAll(const ['Ahmedabad', 'Bengaluru', 'Pune', 'Mumbai', 'Delhi']),
    );
    expect(
      roomiePeople.where((person) => person.likesYou).length,
      greaterThanOrEqualTo(1),
    );

    final router = GoRouter(
      initialLocation: RoutePaths.roomie,
      routes: roomieRoutes(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomieViewerProvider.overrideWithValue(
            const RoomieViewer(isVerified: true, isPremium: true),
          ),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Find Your Roomie'), findsOneWidget);
    expect(find.text('Set your preferences'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);

    await tester.tap(find.byKey(const Key('roomie-set-preferences')));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('roomie-locality-Koramangala')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('roomie-locality-Indiranagar')));
    await tester.pump();

    final scrollable = find.byElementPredicate((element) {
      final widget = element.widget;
      if (widget is! Scrollable || widget.axis != Axis.vertical) {
        return false;
      }
      if (element.findAncestorWidgetOfExactType<EditableText>() != null) {
        return false;
      }
      return element.findAncestorWidgetOfExactType<ListView>() != null;
    });
    await tester.scrollUntilVisible(
      find.byKey(const Key('roomie-occupation')),
      400,
      scrollable: scrollable,
    );
    await tester.enterText(
      find.byKey(const Key('roomie-occupation')),
      'Product designer',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('roomie-open-lifestyle')),
      400,
      scrollable: scrollable,
    );
    expect(find.text('Lifestyle & Preferences'), findsOneWidget);
    await tester.tap(find.byKey(const Key('roomie-open-lifestyle')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Your lifestyle details will be visible only to verified & premium users.',
      ),
      findsOneWidget,
    );
    expect(find.text('Drinking'), findsOneWidget);
    expect(find.text('Food Preference'), findsOneWidget);
    expect(find.text('Cook myself'), findsOneWidget);
    expect(find.text('0/200'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('roomie-save')),
      500,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const Key('roomie-save')));
    await tester.pumpAndSettle();

    expect(find.text('Preferences saved'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);

    await tester.tap(find.byKey(const Key('roomie-see-matches')));
    await tester.pumpAndSettle();

    expect(find.text('Mira Shah, 26'), findsOneWidget);
    expect(find.textContaining('overlap'), findsWidgets);
    expect(find.textContaining('%'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('roomie-card-mira')));
    await tester.pumpAndSettle();

    expect(find.text('Compatibility'), findsOneWidget);
    expect(find.text('Budget'), findsOneWidget);
    expect(find.text('Locality'), findsOneWidget);
    expect(find.text('Move-in'), findsOneWidget);
    expect(find.text('Lifestyle'), findsOneWidget);
    expect(find.textContaining('Food preference: Vegetarian'), findsOneWidget);
    expect(
      find.textContaining('Quiet kitchen and early nights.'),
      findsOneWidget,
    );
    expect(find.text(roomieLifestyleGate), findsNothing);
    expect(find.text('Interested'), findsOneWidget);
    expect(find.text('Pass'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('roomie-interested')));
    await tester.pumpAndSettle();

    expect(find.text("It's a match!"), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('roomie-open-chat')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Shall we look at flats'), findsOneWidget);
    expect(find.text('Explore flats together'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('roomie-chat-input')),
      'Saturday works.',
    );
    await tester.tap(find.byKey(const Key('roomie-send')));
    await tester.pump();
    expect(find.text('Saturday works.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('roomie-explore-together')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Combined budget'), findsOneWidget);
    expect(find.textContaining('Koramangala'), findsWidgets);
    expect(find.text('Shared shortlist'), findsOneWidget);
    expect(
      find.byKey(const Key('roomie-shortlist-blr-koramangala')),
      findsOneWidget,
    );
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.textContaining('Sign in'), findsNothing);

    await tester.tap(
      find.byKey(const Key('roomie-shortlist-add-blr-indiranagar')),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('roomie-shortlist-blr-indiranagar')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('roomie-shortlist-blr-koramangala')),
      findsOneWidget,
    );
  });
}
