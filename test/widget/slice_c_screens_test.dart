import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/notifications/demo_notification_gateway.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/notification_providers.dart';
import 'package:homizi/features/notifications/notifications_screen.dart';
import 'package:homizi/features/profile/profile_hub_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/support/help_screen.dart';
import 'package:homizi/features/support/support_providers.dart';
import 'package:homizi/features/tools/deposit_screen.dart';
import 'package:homizi/features/tools/receipt_screen.dart';
import 'package:homizi/features/tools/split_screen.dart';
import 'package:homizi/features/tools/tools_screen.dart';
import 'package:homizi/l10n/app_localizations.dart';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile hub shows the meter, activity, and role', (
    tester,
  ) async {
    final accounts = DemoAccountGateway();
    await accounts.saveTenantProfile(
      const TenantProfile(
        displayName: 'Ananya Iyer',
        occupation: 'Product designer',
        bio: 'Looking for a quiet furnished room in Koramangala.',
        preferences: TenantPreferences(
          budgetMinInr: 18000,
          budgetMaxInr: 28000,
          localities: ['Koramangala'],
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWith(_ReadySession.new),
          accountGatewayProvider.overrideWithValue(accounts),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ProfileHubScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-initials')), findsOneWidget);
    expect(find.text('AI'), findsNWidgets(2));
    expect(find.byKey(const Key('public-profile-initials')), findsOneWidget);
    expect(find.byKey(const Key('public-profile-name')), findsOneWidget);
    expect(find.text('Profile 6 of 6'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-role')),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('profile-role')), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-activity')),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('My activity'), findsOneWidget);
    expect(find.textContaining('Sunlit 2BHK in Koramangala'), findsOneWidget);
    expect(find.textContaining('Recently viewed'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('tools grid opens the rent split calculator', (tester) async {
    final router = GoRouter(
      initialLocation: RoutePaths.tools,
      routes: [
        GoRoute(
          path: RoutePaths.tools,
          builder: (context, state) => const ToolsScreen(),
        ),
        GoRoute(
          path: RoutePaths.rentSplit,
          builder: (context, state) => const SplitScreen(),
        ),
        GoRoute(
          path: RoutePaths.rentReceipt,
          builder: (context, state) => const ReceiptScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tool-receipt')), findsOneWidget);
    expect(RoutePaths.tools, '/tools');
    await tester.scrollUntilVisible(
      find.byKey(const Key('tool-split')),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('tool-split')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('split-calculate')),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('split-calculate')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('split-band')),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.byKey(const Key('split-band')), findsOneWidget);
    expect(find.text('Above a third'), findsOneWidget);
    expect(find.textContaining('₹30,000'), findsWidgets);
  });

  testWidgets('a receipt is saved and can be listed again', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ReceiptScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('receipt-tenant')),
      'Ananya Iyer',
    );
    await tester.enterText(
      find.byKey(const Key('receipt-owner')),
      'Rohan Mehta',
    );
    await tester.enterText(
      find.byKey(const Key('receipt-address')),
      '18, 4th Cross, Koramangala 5th Block, Bengaluru',
    );
    await tester.enterText(find.byKey(const Key('receipt-rent')), '28000');
    await tester.enterText(find.byKey(const Key('receipt-pan')), 'abcde1234f');
    await tester.scrollUntilVisible(
      find.byKey(const Key('receipt-save')),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('receipt-save')));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ananya Iyer'),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('Ananya Iyer'), findsWidgets);
    expect(find.byKey(const Key('receipt-empty')), findsNothing);
    expect(find.textContaining('ABCDE1234F'), findsNothing);
  });

  testWidgets('deposit refund updates after a deduction and a reminder', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const DepositScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('deposit-label')),
      'Koramangala 5th Block',
    );
    await tester.enterText(find.byKey(const Key('deposit-paid')), '84000');
    await tester.enterText(find.byKey(const Key('deposit-due')), '2026-12-01');
    await tester.tap(find.byKey(const Key('deposit-save')));
    await tester.pumpAndSettle();

    expect(find.textContaining('₹84,000'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('deduction-label')),
      400,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(
      find.byKey(const Key('deduction-label')),
      'Painting',
    );
    await tester.enterText(find.byKey(const Key('deduction-amount')), '8000');
    await tester.tap(find.byKey(const Key('deduction-add')));
    await tester.pumpAndSettle();
    expect(find.textContaining('₹76,000'), findsOneWidget);

    await tester.tap(find.byKey(const Key('deposit-remind')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reminder added'), findsOneWidget);
  });

  testWidgets('notifications filter by category and dismiss on swipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = DemoNotificationGateway();
    gateway.seed(
      InboxNotice(
        id: 'notice-chat',
        type: 'message',
        matchId: '88888888-8888-4888-8888-888888888801',
        createdAt: DateTime.utc(2026, 10, 17, 9),
      ),
    );
    gateway.seed(
      InboxNotice(
        id: 'notice-system',
        type: 'deposit_reminder',
        createdAt: DateTime.utc(2026, 10, 17, 10),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [notificationGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(home: NotificationsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New message on a match.'), findsOneWidget);
    expect(find.text('Deposit refund reminder.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-system')));
    await tester.pumpAndSettle();
    expect(find.text('Deposit refund reminder.'), findsOneWidget);
    expect(find.text('New message on a match.'), findsNothing);

    await tester.drag(
      find.byKey(const Key('notice-sentence-notice-system')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deposit refund reminder.'), findsNothing);
    expect(find.text(InboxCopy.demoDismissed), findsOneWidget);

    await tester.tap(find.byKey(const Key('notification-preferences')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pref-matches')));
    await tester.tap(find.byKey(const Key('save-notification-prefs')));
    await tester.pumpAndSettle();
    expect(find.text(InboxCopy.preferencesSaved), findsOneWidget);
    expect((await gateway.loadPreferences()).matches, isFalse);
  });

  testWidgets('help search and a support ticket stay free of contact details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HelpScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('How do I delete my account?'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('faq-search')), 'checkout');
    await tester.pumpAndSettle();
    expect(find.text('How do I delete my account?'), findsNothing);
    expect(find.text('Can I pay for a listing here?'), findsOneWidget);
    expect(find.textContaining('Payments are not supported'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Contact'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('support-message')),
      'Need help understanding a visit for a Koramangala flat.',
    );
    await tester.tap(find.byKey(const Key('submit-support')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('support-note')), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);

    final tickets = await ProviderScope.containerOf(
      tester.element(find.byType(HelpScreen)),
    ).read(supportGatewayProvider).loadMine();
    expect(tickets, isNotEmpty);
    expect(tickets.single.message, isNot(contains('@')));
  });
}
