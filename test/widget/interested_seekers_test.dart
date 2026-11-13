import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/roles/seeker_matches_screen.dart';
import 'package:homizi/features/seekers/seeker_shortlist.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('interested seekers scores, filters, and opens a preview', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = MemorySeekerDeckStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [seekerDeckStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const SeekerMatchesScreen(title: 'Interested Seekers'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Interested Seekers'), findsOneWidget);
    expect(find.text('People looking for a place like yours'), findsOneWidget);
    expect(find.text('Ananya Iyer'), findsOneWidget);
    expect(find.textContaining('Neelam'), findsNothing);
    expect(find.textContaining('aadhaar'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
    expect(
      find.textContaining('Contact stays hidden until you both match'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('seeker-city')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seeker-city-Ahmedabad')));
    await tester.pumpAndSettle();

    expect(find.text('Rohan Verma'), findsOneWidget);
    expect(find.text('Ananya Iyer'), findsNothing);
    expect(find.byKey(const Key('seeker-match-rohan-verma')), findsOneWidget);

    await tester.tap(find.byKey(const Key('seeker-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seeker-filter-verified')));
    await tester.tap(find.byKey(const Key('seeker-filter-apply')));
    await tester.pumpAndSettle();
    expect(find.text('Dev Patel'), findsNothing);
    expect(find.text('Rohan Verma'), findsOneWidget);

    await tester.tap(find.byKey(const Key('seeker-shortlist-rohan-verma')));
    await tester.pump();
    expect(store.saved?.shortlisted, contains('rohan-verma'));
    await tester.tap(find.byKey(const Key('seeker-tab-shortlist')));
    await tester.pump();
    expect(find.text('Rohan Verma'), findsOneWidget);
    expect(find.text('Aditi Mehta'), findsNothing);

    await tester.tap(find.byKey(const Key('seeker-tab-all')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('seeker-card-rohan-verma')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('seeker-preview')), findsOneWidget);
    expect(find.text('Seeker Requirement'), findsOneWidget);
    expect(find.text('Lifestyle & Living Preferences'), findsOneWidget);
    expect(find.text('House Rules Preference'), findsOneWidget);
    expect(find.text("Why It's a Good Fit for Your Property"), findsOneWidget);
    expect(find.text('Seeker Info'), findsOneWidget);
    expect(find.text('Verified Seeker'), findsOneWidget);
    expect(find.text('Match for Your Property'), findsOneWidget);
    expect(find.textContaining('aadhaar'), findsNothing);
    expect(find.text('Not a Fit'), findsOneWidget);
    expect(find.text('Maybe Later'), findsOneWidget);
    expect(find.text('Message & Connect'), findsWidgets);

    await tester.ensureVisible(
      find.byKey(const Key('seeker-tab-compatibility')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seeker-tab-compatibility')));
    await tester.pumpAndSettle();
    expect(find.text('Compatibility'), findsWidgets);

    await tester.tap(find.byKey(const Key('seeker-maybe-later')));
    await tester.pumpAndSettle();
    expect(find.text('Saved for later'), findsOneWidget);
    expect(store.saved?.later, contains('rohan-verma'));
    await tester.tap(find.byKey(const Key('seeker-confirm-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('seeker-message')));
    await tester.pumpAndSettle();
    expect(find.text('Chat is ready'), findsOneWidget);
    expect(
      find.textContaining('verification documents stay hidden'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('seeker-confirm-next')));
    await tester.pumpAndSettle();
    expect(find.byType(ChatScreen), findsOneWidget);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);

    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('seeker-not-fit')));
    await tester.pumpAndSettle();
    expect(find.text('Not a fit'), findsOneWidget);
    await tester.tap(find.byKey(const Key('seeker-confirm-next')));
    await tester.pumpAndSettle();
    expect(find.text('Rohan Verma'), findsNothing);
    expect(store.saved?.dismissed, contains('rohan-verma'));
    expect(find.byType(SeekerMatchesScreen), findsOneWidget);
  });

  testWidgets('match colour stays on the success green', (tester) async {
    expect(HomiziColors.success, const Color(0xFF16803C));
  });
}
