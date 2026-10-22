import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_screen.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/public_profile.dart';

void main() {
  testWidgets('create profile runs through to Profile Completed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final accounts = DemoAccountGateway();
    final router = GoRouter(
      initialLocation: RoutePaths.profileCreate,
      routes: [
        GoRoute(
          path: RoutePaths.profileCreate,
          builder: (context, state) => const ProfileCreateScreen(),
        ),
        GoRoute(
          path: RoutePaths.demoDone,
          builder: (context, state) => DemoSuccessScreen(
            title: state.uri.queryParameters['title'] ?? 'Saved',
            detail: state.uri.queryParameters['detail'] ?? 'Done',
          ),
        ),
        GoRoute(
          path: RoutePaths.home,
          builder: (context, state) =>
              const Scaffold(body: Text('Home reached')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
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
          accountGatewayProvider.overrideWith((ref) => accounts),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOMIZI'), findsOneWidget);
    expect(find.text('Basic Information'), findsOneWidget);
    expect(find.text('Tell us about yourself'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('profile-create-first')),
      'Priya',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-last')),
      'Shah',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-nickname')),
      'Asha',
    );
    await tester.enterText(find.byKey(const Key('profile-create-age')), '26');
    await _choose(tester, const Key('profile-create-gender-0'), 'Woman');
    await _choose(tester, const Key('profile-create-occupation-0'), 'Student');
    expect(find.text('Private, never shown publicly'), findsWidgets);
    expect(find.text('Shown on your public profile'), findsOneWidget);
    await _continue(tester);
    expect(find.text('Verify Mobile & Email'), findsOneWidget);
    expect(find.text('Keep your account secure'), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-create-back')));
    await tester.pumpAndSettle();
    expect(find.text('Basic Information'), findsOneWidget);
    await _continue(tester);
    expect(find.text('Verify Mobile & Email'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('profile-create-mobile')),
      '9876543210',
    );
    await tester.tap(find.byKey(const Key('profile-create-mobile-send')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-create-mobile-otp')),
      '000000',
    );
    await tester.tap(find.byKey(const Key('profile-create-mobile-verify')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('profile-create-mobile-check')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('profile-create-email')),
      'asha@example.com',
    );
    await tester.ensureVisible(
      find.byKey(const Key('profile-create-email-send')),
    );
    await tester.tap(find.byKey(const Key('profile-create-email-send')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-create-email-otp')),
      '000000',
    );
    await tester.ensureVisible(
      find.byKey(const Key('profile-create-email-verify')),
    );
    await tester.tap(find.byKey(const Key('profile-create-email-verify')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-create-email-check')), findsOneWidget);

    await _continue(tester);
    expect(find.text('Aadhaar Verification'), findsOneWidget);
    expect(find.text('Verify your identity with Aadhaar'), findsOneWidget);
    expect(find.text('Enter Aadhaar number'), findsOneWidget);
    expect(find.text('Verify with OTP'), findsOneWidget);
    expect(find.text('Your data is secure'), findsOneWidget);
    expect(
      find.text('We use secure and government authorized verification.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('profile-create-aadhaar')),
      '234123412341',
    );
    await tester.pump();
    final aadhaar = tester.widget<TextField>(
      find.byKey(const Key('profile-create-aadhaar')),
    );
    expect(aadhaar.controller?.text, 'XXXX XXXX 2341');

    await tester.tap(find.byKey(const Key('profile-create-aadhaar-send')));
    await tester.pumpAndSettle();
    expect(
      find.text('Demo verification — Digio is not live. The code is 000000.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-aadhaar-otp')),
      '000000',
    );
    await tester.ensureVisible(
      find.byKey(const Key('profile-create-aadhaar-verify')),
    );
    await tester.tap(find.byKey(const Key('profile-create-aadhaar-verify')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('profile-create-aadhaar-check')),
      findsOneWidget,
    );

    await _continue(tester);
    expect(find.text('Selfie Verification'), findsOneWidget);
    expect(
      find.text('Take a clear selfie to confirm your identity'),
      findsOneWidget,
    );
    expect(find.text('Look into the camera'), findsOneWidget);
    expect(find.text('Ensure good lighting'), findsOneWidget);
    expect(find.text('Keep your face clearly visible'), findsOneWidget);
    expect(find.text('Capture Selfie'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('profile-create-sample')));
    await tester.tap(find.byKey(const Key('profile-create-sample')));
    await tester.pump();
    expect(find.text('Sample photo for this demo'), findsOneWidget);
    expect(find.text('Blink once, then confirm.'), findsOneWidget);
    expect(
      find.byKey(const Key('profile-create-selfie-ready')),
      findsOneWidget,
    );
    final toggle = tester.widget<Switch>(
      find.byKey(const Key('profile-create-photo-toggle')),
    );
    expect(toggle.value, isFalse);

    await tester.ensureVisible(
      find.byKey(const Key('profile-create-liveness')),
    );
    await tester.tap(find.byKey(const Key('profile-create-liveness')));
    await tester.pumpAndSettle();
    expect(find.text('Liveness check passed'), findsOneWidget);
    expect(find.text('Confirm the liveness check.'), findsNothing);
    expect(
      find.byKey(const Key('profile-create-liveness-check')),
      findsOneWidget,
    );

    await _continue(tester);
    expect(find.text('Profile Completed!'), findsOneWidget);
    expect(
      find.text('Your profile is verified and ready to use Homizi.'),
      findsOneWidget,
    );
    expect(find.text('Mobile Verified'), findsWidgets);
    expect(find.text('Email Verified'), findsWidgets);
    expect(find.text('Aadhaar Verified'), findsOneWidget);
    expect(find.text('Selfie Verified'), findsWidgets);
    expect(find.text('Identity Verified'), findsOneWidget);
    expect(find.text('Priya'), findsNothing);
    expect(find.text('Shah'), findsNothing);

    await tester.tap(find.text('Start Exploring'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-success-screen')), findsOneWidget);
    expect(find.text('Profile ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-success-home')));
    await tester.pumpAndSettle();
    expect(find.text('Home reached'), findsOneWidget);

    final saved = await accounts.loadTenantProfile();
    expect(saved.displayName, 'Asha');
    expect(saved.occupation, 'Student');
    expect(saved.ageRange, '25-30');
    expect(saved.avatarUrl, isNull);
    expect(saved.verification, VerificationStatus.mockVerified);

    final container = ProviderScope.containerOf(
      tester.element(find.text('Home reached')),
    );
    final store = container.read(profileCreateStoreProvider);
    expect(store.wroteProfile, isTrue);
    expect(store.draft.aadhaarLast4, '2341');
    expect(store.draft.mobileVerified, isTrue);
    expect(store.draft.emailVerified, isTrue);
    expect(store.draft.aadhaarVerified, isTrue);
    expect(store.draft.selfieVerified, isTrue);
    expect(store.draft.livenessPassed, isTrue);
    expect(store.draft.nickname, 'Asha');
    expect(store.draft.firstName, 'Priya');
    final row = profileCreateColumns(store.draft).toProfileRow();
    expect(profileRowHidesPrivateColumns(row), isTrue);
    expect(row['display_name'], 'Asha');
    expect(row.containsKey('first_name'), isFalse);
    final profile = container.read(ownVerificationProvider);
    expect(profile.isVerified, isTrue);
    expect(profile.publicName, 'Asha');
    expect(profile.showPhotoToVerifiedUsers, isFalse);
  });

  testWidgets('captured selfie, I blinked, and Continue open the next step', (
    tester,
  ) async {
    const width = 390.0;
    tester.view.physicalSize = const Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ProfileCreateStore(DemoAccountGateway())
      ..draft = const ProfileCreateDraft(
        step: 3,
        firstName: 'Priya',
        lastName: 'Shah',
        nickname: 'Asha',
        mobileVerified: true,
        emailVerified: true,
        aadhaarVerified: true,
      );
    final router = GoRouter(
      initialLocation: RoutePaths.profileCreate,
      routes: [
        GoRoute(
          path: RoutePaths.profileCreate,
          builder: (context, state) => const ProfileCreateScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
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
          profileCreateStoreProvider.overrideWith((ref) => store),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selfie Verification'), findsOneWidget);
    expect(find.text('Liveness check passed'), findsNothing);

    final capture = find.byKey(const Key('profile-create-capture'));
    await tester.ensureVisible(capture);
    _expectOnScreen(tester, capture, width);

    // The sample photo is the demo capture when the camera cannot open.
    await tester.ensureVisible(find.byKey(const Key('profile-create-sample')));
    await tester.tap(find.byKey(const Key('profile-create-sample')));
    await tester.pumpAndSettle();

    expect(find.text('Blink once, then confirm.'), findsOneWidget);
    expect(find.text('I blinked'), findsOneWidget);
    expect(find.text('Liveness check passed'), findsNothing);
    expect(find.text('Confirm the liveness check.'), findsNothing);
    expect(
      publicProfileFromDraft(store.draft).badges,
      isNot(contains('Selfie Verified')),
    );

    final blink = find.byKey(const Key('profile-create-liveness'));
    final toggle = find.byKey(const Key('profile-create-photo-toggle'));
    await tester.ensureVisible(blink);
    _expectOnScreen(tester, blink, width);
    await tester.ensureVisible(toggle);
    _expectOnScreen(tester, toggle, width);
    expect(tester.widget<Switch>(toggle).value, isFalse);
    expect(tester.takeException(), isNull);

    await tester.tap(blink);
    await tester.pumpAndSettle();
    expect(find.text('Liveness check passed'), findsOneWidget);
    expect(find.text('Confirm the liveness check.'), findsNothing);
    expect(store.draft.livenessPassed, isTrue);
    expect(store.draft.selfieVerified, isTrue);
    expect(
      publicProfileFromDraft(store.draft).badges,
      contains('Selfie Verified'),
    );

    await _continue(tester);
    expect(find.text('Profile Completed!'), findsOneWidget);
    expect(find.byKey(const Key('badge-Selfie Verified')), findsOneWidget);
    expect(find.byKey(const Key('profile-verified-selfie')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _choose(WidgetTester tester, Key field, String option) async {
  await tester.ensureVisible(find.byKey(field));
  await tester.tap(find.byKey(field));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void _expectOnScreen(WidgetTester tester, Finder finder, double width) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(16));
  expect(rect.right, lessThanOrEqualTo(width - 16));
  expect(rect.width, greaterThan(0));
}

Future<void> _continue(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('profile-create-continue')));
  await tester.tap(find.byKey(const Key('profile-create-continue')));
  await tester.pumpAndSettle();
}
