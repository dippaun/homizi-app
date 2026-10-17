import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

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

void main() {
  testWidgets('the app boots in light and keeps a dark scheme ready', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: const HomiziApp(),
      ),
    );
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.theme?.scaffoldBackgroundColor, HomiziColors.white);
    expect(app.darkTheme?.scaffoldBackgroundColor, HomiziColors.night);
    expect(app.darkTheme?.colorScheme.onPrimary, HomiziColors.ink);
    expect(
      app.theme?.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<ZoomPageTransitionsBuilder>(),
    );
  });

  testWidgets('onboarding is a three-slide carousel with consent', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: HomiziApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.byKey(const Key('onboarding-carousel')), findsOneWidget);
    expect(find.text('Slide 1 of 3'), findsWidgets);
    expect(find.text('Find a home without the noise.'), findsOneWidget);
    expect(find.text('Agree and continue'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('onboarding-carousel')),
      const Offset(-400, 0),
      1200,
    );
    await tester.pumpAndSettle();

    expect(find.text('Slide 2 of 3'), findsWidgets);
    expect(find.text('Profiles with a verification status'), findsOneWidget);
    expect(find.byKey(const Key('consent-checkbox')), findsOneWidget);
  });

  testWidgets('explore cards show rent, deposit, distance, and a save heart', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('₹22,000/mo'), findsWidgets);
    expect(find.text('Deposit ₹80,000'), findsWidgets);
    expect(find.text('About 6 km'), findsWidgets);
    expect(find.text('2 BHK'), findsWidgets);
    expect(find.text('Furnished'), findsWidgets);
    expect(find.text('Verified'), findsWidgets);
    expect(find.byIcon(Icons.favorite_border), findsWidgets);
  });

  testWidgets('discover shows photos and a sample match percent', (
    tester,
  ) async {
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
        of: find.byType(NavigationBar),
        matching: find.text('Swipe'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('100% match'), findsOneWidget);
    expect(find.text('Sunlit 2BHK in Koramangala'), findsOneWidget);
    expect(find.byType(PageView), findsWidgets);
    expect(find.byKey(const Key('swipe-card')), findsOneWidget);
    expect(find.byKey(const Key('discover-like')), findsNothing);
    expect(find.byKey(const Key('swipe-undo')), findsOneWidget);
  });

  testWidgets('listing detail keeps a static map preview', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('listing-card-lst_koramangala')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('map-preview')), findsOneWidget);
    expect(find.text('Map preview'), findsOneWidget);
    expect(
      find.text(
        'The street address stays off this map until a visit is agreed.',
      ),
      findsOneWidget,
    );
    expect(find.text('100% match'), findsOneWidget);
    expect(HomiziTheme.light().useMaterial3, isTrue);
  });
}
