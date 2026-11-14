import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/host_flow/listing_flow.dart';
import 'package:homizi/features/inventory/demo_inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/post_property/partner_flow_screen.dart';
import 'package:homizi/features/post_property/post_confirm_screen.dart';
import 'package:homizi/features/post_property/post_otp_screen.dart';
import 'package:homizi/features/post_property/post_property_choice.dart';
import 'package:homizi/features/post_property/post_property_chooser_screen.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shared_home/host_shared_home_screen.dart';

const _demoConfig = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

class _HostSession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'meera@example.test',
      role: AccountRole.host,
      homiziWire: 'host',
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('application ids look like PP20261115-4587', () {
    expect(
      partnerApplicationId(DateTime(2026, 11, 15), 4587),
      'PP20261115-4587',
    );
    expect(choiceForRole(HomiziRole.host), PostPropertyChoice.owner);
  });

  testWidgets('chooser routes owner, partner, and shared room', (tester) async {
    tall(tester);
    final router = GoRouter(
      initialLocation: RoutePaths.postProperty,
      routes: [
        GoRoute(
          path: RoutePaths.postProperty,
          builder: (context, state) => const PostPropertyChooserScreen(),
        ),
        GoRoute(
          path: RoutePaths.postOwner,
          builder: (context, state) =>
              const ListingFlow(postFlow: true, showMarketing: false),
        ),
        GoRoute(
          path: RoutePaths.postPartner,
          builder: (context, state) => const PartnerFlowScreen(),
        ),
        GoRoute(
          path: RoutePaths.postShared,
          builder: (context, state) =>
              const HostSharedHomeScreen(postChrome: true),
        ),
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          inventoryGatewayProvider.overrideWith(
            (ref) => DemoInventoryGateway(),
          ),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Post Property'), findsOneWidget);
    expect(find.text('Post as Owner'), findsOneWidget);
    expect(find.text('Post as Property Partner'), findsOneWidget);
    expect(find.text('Post as Shared Room / Full House'), findsOneWidget);
    expect(find.byKey(const Key('post-property-continue')), findsOneWidget);

    Future<void> open(Key choice, Key landed) async {
      router.go(RoutePaths.postProperty);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(choice));
      await tester.pump();
      await tester.tap(find.byKey(const Key('post-property-continue')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(landed), findsOneWidget);
    }

    await open(const Key('post-choice-owner'), const Key('post-owner-flow'));
    expect(find.text('Basic Info'), findsWidgets);
    expect(find.byKey(const Key('listing-title')), findsOneWidget);

    await open(
      const Key('post-choice-partner'),
      const Key('post-partner-type'),
    );
    expect(find.text('Select Partner Type'), findsOneWidget);

    await open(
      const Key('post-choice-shared'),
      const Key('host-shared-screen'),
    );
    expect(find.byKey(const Key('post-property-back')), findsOneWidget);
    expect(find.byKey(const Key('post-property-home')), findsOneWidget);
  });

  testWidgets('a host role preselects Post as Owner', (tester) async {
    tall(tester);
    final router = GoRouter(
      initialLocation: RoutePaths.postProperty,
      routes: [
        GoRoute(
          path: RoutePaths.postProperty,
          builder: (context, state) => const PostPropertyChooserScreen(),
        ),
        GoRoute(
          path: RoutePaths.postOwner,
          builder: (context, state) => const Scaffold(
            body: Text('owner-landed', key: Key('owner-landed')),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          sessionProvider.overrideWith(_HostSession.new),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('post-property-continue')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('owner-landed')), findsOneWidget);
  });

  testWidgets('partner stepper verifies OTP and confirms the application', (
    tester,
  ) async {
    tall(tester);
    final router = GoRouter(
      initialLocation: RoutePaths.postPartner,
      routes: [
        GoRoute(
          path: RoutePaths.postPartner,
          builder: (context, state) => const PartnerFlowScreen(),
        ),
        GoRoute(
          path: RoutePaths.postPartnerOtp,
          builder: (context, state) => const PostOtpScreen(),
        ),
        GoRoute(
          path: RoutePaths.postPartnerDone,
          builder: (context, state) => const PartnerSuccessScreen(),
        ),
        GoRoute(
          path: RoutePaths.postPartnerHome,
          builder: (context, state) =>
              const Scaffold(body: Text('desk', key: Key('partner-desk'))),
        ),
        GoRoute(
          path: RoutePaths.login,
          builder: (context, state) => const Scaffold(body: Text('Sign in')),
        ),
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) => const Scaffold(body: Text('Home')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(_demoConfig)],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('post-partner-type')), findsOneWidget);
    await tester.tap(find.byKey(const Key('post-partner-builder')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('post-partner-continue')));
    await tester.pump();
    expect(find.byKey(const Key('post-step-0')), findsOneWidget);
    expect(find.text('Basic Info'), findsWidgets);

    await tester.enterText(
      find.byKey(const Key('post-full-name')),
      'Meera Krishnan',
    );
    await tester.enterText(find.byKey(const Key('post-mobile')), '9876543210');
    await tester.enterText(
      find.byKey(const Key('post-email')),
      'meera@example.com',
    );
    await tester.tap(find.byKey(const Key('post-send-mobile-otp')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('post-otp-screen')), findsOneWidget);
    expect(find.byKey(const Key('otp-box-0')), findsOneWidget);
    expect(find.byKey(const Key('otp-box-5')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('post-otp-field')), '000000');
    await tester.tap(find.byKey(const Key('post-otp-verify')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Mobile verified'), findsOneWidget);

    await tester.tap(find.byKey(const Key('post-partner-continue')));
    await tester.pump();
    expect(find.text('Business Details'), findsWidgets);
    expect(find.text('Builder-Developer'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('post-business-address')),
      '12, 4th Cross, Indiranagar, Bengaluru',
    );
    await tester.enterText(
      find.byKey(const Key('post-operating-area')),
      'Indiranagar, Bengaluru',
    );
    await tester.enterText(
      find.byKey(const Key('post-about')),
      'Homes across Bengaluru for working professionals.',
    );
    expect(find.byKey(const Key('post-about-count')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('post-partner-continue')));
    await tester.tap(find.byKey(const Key('post-partner-continue')));
    await tester.pump();
    expect(find.text('Verification'), findsWidgets);
    expect(find.byKey(const Key('post-verify-later')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('post-verify-later')));
    await tester.tap(find.byKey(const Key('post-verify-later')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('post-partner-success')), findsOneWidget);
    expect(find.text('Registration Successful!'), findsOneWidget);
    final id = tester.widget<Text>(
      find.byKey(const Key('post-application-id')),
    );
    expect(id.data, matches(RegExp(r'^PP\d{8}-\d{4}$')));
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle));
    expect(icon.color, HomiziColors.success);

    await tester.tap(find.byKey(const Key('post-go-dashboard')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('partner-desk')), findsOneWidget);
  });
}
