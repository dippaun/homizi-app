import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/host/host_onboarding_screen.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';

void main() {
  testWidgets('host onboarding ends on a confirmation page', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accounts = DemoAccountGateway();
    final router = _router();
    addTearDown(router.dispose);

    await tester.pumpWidget(_app(router, accounts: accounts));
    await tester.pumpAndSettle();

    expect(find.text('Become a Host on Homizi'), findsOneWidget);
    expect(find.text('1/8'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);

    await _continue(tester);
    expect(find.text('Choose Your Category'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byKey(const Key('host-onboard-back')));
    await tester.pumpAndSettle();
    expect(find.text('Become a Host on Homizi'), findsOneWidget);
    await _continue(tester);

    await tester.tap(find.byKey(const Key('host-role-owner')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('host-add-role')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('host-role-broker')));
    await tester.tap(find.byKey(const Key('host-role-broker')));
    await tester.pump();
    expect(
      find.textContaining('One account can hold more than one role.'),
      findsOneWidget,
    );
    await _continue(tester);
    expect(find.text('Complete Your Profile'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('host-full-name')),
      'Priya Shah',
    );
    await tester.enterText(find.byKey(const Key('host-nickname')), 'Asha');
    await tester.enterText(find.byKey(const Key('host-mobile')), '9820098200');
    await tester.enterText(
      find.byKey(const Key('host-email')),
      'asha@example.com',
    );
    await _continue(tester);
    expect(find.text('Verify Your Identity'), findsOneWidget);
    expect(find.byKey(const Key('host-registration')), findsNothing);

    await tester.tap(find.byKey(const Key('host-mobile-send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('host-mobile-otp')), '000000');
    await tester.tap(find.byKey(const Key('host-mobile-verify')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-mobile-check')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('host-email-send')));
    await tester.tap(find.byKey(const Key('host-email-send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('host-email-otp')), '000000');
    await tester.ensureVisible(find.byKey(const Key('host-email-verify')));
    await tester.tap(find.byKey(const Key('host-email-verify')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-email-check')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('host-aadhaar')),
      '234123412341',
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('host-aadhaar')))
          .controller
          ?.text,
      'XXXX XXXX 2341',
    );
    await tester.tap(find.byKey(const Key('host-aadhaar-send')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('host-aadhaar-otp')), '000000');
    await tester.ensureVisible(find.byKey(const Key('host-aadhaar-verify')));
    await tester.tap(find.byKey(const Key('host-aadhaar-verify')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-aadhaar-check')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('host-sample-photo')));
    await tester.tap(find.byKey(const Key('host-sample-photo')));
    await tester.pump();
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const Key('host-photo-toggle')),
    );
    expect(toggle.value, isFalse);
    await tester.ensureVisible(find.byKey(const Key('host-liveness')));
    await tester.tap(find.byKey(const Key('host-liveness')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('host-liveness-check')), findsOneWidget);

    await _continue(tester);
    expect(find.text('Additional Details'), findsOneWidget);
    expect(find.byKey(const Key('host-company-name')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('host-bio')),
      'I share a furnished room near Andheri station.',
    );
    await tester.tap(
      find.byKey(const Key('host-response-Replies within 24 hours')),
    );
    await tester.tap(find.byKey(const Key('host-pref-Working professional')));
    await tester.tap(find.byKey(const Key('host-plan-free')));
    await tester.pump();
    await _continue(tester);

    expect(find.byKey(const Key('host-trust-identity')), findsOneWidget);
    expect(find.byKey(const Key('host-trust-property')), findsOneWidget);
    expect(find.text('Priya Shah'), findsNothing);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.textContaining('9820098200'), findsNothing);
    expect(find.textContaining('asha@example.com'), findsNothing);
    expect(find.byKey(const Key('host-privacy-note')), findsOneWidget);
    expect(find.byKey(const Key('broker-chip')), findsWidgets);
    expect(find.byKey(const Key('host-rohan-example')), findsOneWidget);
    expect(
      find.byKey(const Key('host-auth-status-owner_document')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('host-auth-status-owner_document')),
          )
          .data,
      'Not submitted',
    );
    await tester.ensureVisible(
      find.byKey(const Key('host-auth-submit-owner_document')),
    );
    await tester.tap(find.byKey(const Key('host-auth-submit-owner_document')));
    await tester.pump();
    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('host-auth-status-owner_document')),
          )
          .data,
      'Under review',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('host-auth-status-broker_id')))
          .data,
      'Not submitted',
    );
    expect(find.byKey(const Key('public-profile-photo')), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await _continue(tester);
    expect(find.text('Category-Wise Profiles'), findsOneWidget);
    expect(find.text('Amit Mehta'), findsOneWidget);
    expect(find.text('Neha Sharma'), findsOneWidget);
    expect(find.text('Kunal Verma'), findsOneWidget);
    expect(find.text('UrbanStay Homes'), findsOneWidget);
    expect(find.byKey(const Key('broker-chip')), findsOneWidget);

    await _continue(tester);
    expect(find.text('List with Responsibility'), findsOneWidget);
    expect(find.byKey(const Key('host-rule-0')), findsOneWidget);
    expect(find.byKey(const Key('host-rule-2')), findsOneWidget);
    await _continue(tester);
    expect(find.byKey(const Key('host-onboard-error')), findsOneWidget);

    await tester.tap(find.byKey(const Key('host-responsibility-check')));
    await tester.pump();
    await _continue(tester);
    expect(find.byKey(const Key('demo-success-screen')), findsOneWidget);
    expect(find.text('You are a host on Homizi'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect((await accounts.loadHostProfile()).category, 'owner');
  });

  testWidgets('roomie sharing needs the agreement confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    await _continue(tester);
    await tester.tap(find.byKey(const Key('host-role-roomie')));
    await tester.pump();
    expect(find.byKey(const Key('host-agreement-permit')), findsOneWidget);
    await _continue(tester);
    expect(
      find.text('Confirm that your rental agreement permits sharing.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('host-agreement-permit')));
    await tester.pump();
    await _continue(tester);
    expect(find.text('Complete Your Profile'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
  });

  testWidgets('finished Create Your Profile verification is reused', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accounts = DemoAccountGateway();
    final store = ProfileCreateStore(accounts);
    store.draft = const ProfileCreateDraft(
      firstName: 'Neha',
      lastName: 'Sharma',
      nickname: 'Neha',
      mobile: '9845012345',
      mobileVerified: true,
      mobileOtpSent: true,
      email: 'neha@example.com',
      emailVerified: true,
      emailOtpSent: true,
      aadhaarLast4: '6789',
      aadhaarVerified: true,
      aadhaarOtpSent: true,
      selfieVerified: true,
      livenessPassed: true,
      sampleAvatar: profileSampleAvatar,
    );
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, accounts: accounts, store: store));
    await tester.pumpAndSettle();
    await _continue(tester);
    await tester.tap(find.byKey(const Key('host-role-broker')));
    await tester.pump();
    await _continue(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('host-nickname')))
          .controller
          ?.text,
      'Neha',
    );
    await _continue(tester);
    expect(find.byKey(const Key('host-verification-reused')), findsOneWidget);
    expect(find.byKey(const Key('host-mobile-send')), findsNothing);
    expect(find.byKey(const Key('host-aadhaar')), findsNothing);
    expect(find.byKey(const Key('host-mobile-check')), findsOneWidget);
    expect(find.byKey(const Key('host-aadhaar-check')), findsOneWidget);
    expect(find.byKey(const Key('host-liveness-check')), findsOneWidget);
  });
}

GoRouter _router() {
  return GoRouter(
    initialLocation: RoutePaths.hostOnboard,
    routes: [
      GoRoute(
        path: RoutePaths.hostOnboard,
        builder: (context, state) => const HostOnboardingScreen(),
      ),
      GoRoute(
        path: RoutePaths.demoDone,
        builder: (context, state) => DemoSuccessScreen(
          title: state.uri.queryParameters['title'] ?? '',
          detail: state.uri.queryParameters['detail'] ?? '',
        ),
      ),
      GoRoute(
        path: RoutePaths.home,
        builder: (context, state) => const Scaffold(body: Text('Home reached')),
      ),
    ],
  );
}

Widget _app(
  GoRouter router, {
  DemoAccountGateway? accounts,
  ProfileCreateStore? store,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(
          environment: AppEnvironment.dev,
          supabaseUrl: '',
          supabaseAnonKey: '',
          policyVersion: '2026-10-11-draft',
          demoSkipLogin: true,
        ),
      ),
      if (accounts != null)
        accountGatewayProvider.overrideWith((ref) => accounts),
      if (store != null)
        profileCreateStoreProvider.overrideWith((ref) => store),
    ],
    child: MaterialApp.router(theme: HomiziTheme.light(), routerConfig: router),
  );
}

Future<void> _continue(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('host-onboard-continue')));
  await tester.tap(find.byKey(const Key('host-onboard-continue')));
  await tester.pumpAndSettle();
}
