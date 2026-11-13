import 'dart:convert';
import 'dart:typed_data';

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
import 'package:homizi/features/profile_create/profile_image_source.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Camera implements ProfileImageSource {
  @override
  Future<Uint8List?> captureSelfie() async => _png;

  @override
  Future<Uint8List?> pickProfilePhoto() async => _png;
}

class _NoCamera implements ProfileImageSource {
  @override
  Future<Uint8List?> captureSelfie() async => null;

  @override
  Future<Uint8List?> pickProfilePhoto() async => null;
}

void main() {
  testWidgets('create profile follows the nine steps and leaves Aadhaar open', (
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
        GoRoute(
          path: RoutePaths.terms,
          builder: (context, state) => const Scaffold(body: Text('Terms')),
        ),
        GoRoute(
          path: RoutePaths.privacy,
          builder: (context, state) => const Scaffold(body: Text('Privacy')),
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
          profileImageSourceProvider.overrideWithValue(_Camera()),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HOMIZI'), findsOneWidget);
    expect(find.text('Select Your Role'), findsOneWidget);
    expect(find.text('I am a... (Select one or more)'), findsOneWidget);
    expect(find.text('User Roles on Homizi'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-role-tenant')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-role-host')));
    await tester.pump();
    await _continue(tester);

    expect(find.text('Basic Information'), findsOneWidget);
    expect(find.text('Key Profile Fields'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('profile-create-full-name')),
      'Priya Shah',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-nickname')),
      'Asha',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-surname')),
      'Mehta',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-dob-day')),
      '12',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-dob-month')),
      '12',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-dob-year')),
      '2000',
    );
    await tester.tap(find.byKey(const Key('profile-create-gender-Woman')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-create-occupation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Student').last);
    await tester.pumpAndSettle();
    await _continue(tester);

    expect(find.text('Language Known'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-create-back')));
    await tester.pumpAndSettle();
    expect(find.text('Basic Information'), findsOneWidget);
    await _continue(tester);
    await tester.tap(find.byKey(const Key('profile-language-Hindi')));
    await tester.tap(find.byKey(const Key('profile-language-English')));
    await tester.pump();
    await _continue(tester);

    expect(find.text('Verify Contact'), findsOneWidget);
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
    expect(find.text('Enter Aadhaar number'), findsOneWidget);
    expect(find.text('Verify with OTP'), findsOneWidget);
    expect(
      find.text('We use secure and government authorised verification.'),
      findsOneWidget,
    );
    await _continue(tester);
    expect(find.text(kycComingSoonCopy), findsWidgets);
    await tester.tap(find.byKey(const Key('profile-create-alert-ok')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('profile-aadhaar-unavailable')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('profile-create-aadhaar-check')), findsNothing);
    await _continue(tester);

    expect(find.text('Selfie Verification'), findsOneWidget);
    expect(
      find.text(
        'This selfie is only for verification purposes and will not be visible to other users.',
      ),
      findsOneWidget,
    );
    expect(find.text('Profile Privacy & Control'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('profile-create-capture')));
    await tester.tap(find.byKey(const Key('profile-create-capture')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('profile-create-selfie-ready')),
      findsOneWidget,
    );
    await _continue(tester);

    expect(find.text('Choose Your Profile Photo'), findsOneWidget);
    expect(find.text('Use My Selfie as Profile Photo'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-create-use-selfie')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-create-photo-ready')), findsOneWidget);
    await _continue(tester);

    expect(find.text('Lifestyle & Preferences'), findsWidgets);
    await tester.tap(find.byKey(const Key('profile-smoking-No')));
    await tester.tap(find.byKey(const Key('profile-drinking-Occasional')));
    await tester.tap(find.byKey(const Key('profile-food-Veg')));
    await tester.tap(find.byKey(const Key('profile-cooking-Cook myself')));
    await tester.tap(find.byKey(const Key('profile-cleaning-Myself')));
    await tester.pump();
    await _continue(tester);

    expect(find.text('Terms & Completion'), findsOneWidget);
    expect(find.text('Completion Note'), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-terms')));
    await tester.tap(find.byKey(const Key('profile-privacy')));
    await tester.tap(find.byKey(const Key('profile-consent')));
    await tester.pump();
    await _continue(tester);

    expect(find.text('Profile Completed!'), findsOneWidget);
    expect(
      find.text('Your profile is verified and ready to use Homizi.'),
      findsOneWidget,
    );
    expect(find.text('Mobile Verified'), findsWidgets);
    expect(find.text('Email Verified'), findsWidgets);
    expect(find.text('Selfie Verified'), findsWidgets);
    expect(find.text('Aadhaar Verified'), findsNothing);
    expect(
      find.byKey(const Key('profile-done-aadhaar-pending')),
      findsOneWidget,
    );
    expect(find.text('Priya'), findsNothing);
    expect(find.text('Shah'), findsNothing);
    expect(find.text('Asha Mehta'), findsOneWidget);

    await tester.tap(find.text('Start Exploring'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('demo-success-screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('demo-success-home')));
    await tester.pumpAndSettle();
    expect(find.text('Home reached'), findsOneWidget);

    final saved = await accounts.loadTenantProfile();
    expect(saved.displayName, 'Asha Mehta');
    expect(saved.occupation, 'Student');
    expect(saved.ageRange, '25-30');
    expect(saved.verification, isNot(VerificationStatus.mockVerified));

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('search-properties-screen'))),
    );
    final store = container.read(profileCreateStoreProvider);
    expect(store.draft.aadhaarVerified, isFalse);
    expect(store.draft.aadhaarLast4, isEmpty);
    expect(store.draft.mobileVerified, isTrue);
    expect(store.draft.emailVerified, isTrue);
    expect(store.draft.selfieVerified, isTrue);
    expect(store.draft.roles, containsAll(['tenant', 'host']));
    expect(store.draft.languages, contains('Hindi'));
    expect(store.draft.firstName, 'Priya');
    expect(store.draft.surname, 'Mehta');
    final row = profileCreateColumns(store.draft).toProfileRow();
    expect(profileRowHidesPrivateColumns(row), isTrue);
    expect(row['display_name'], 'Asha Mehta');
    expect(row['identity_verified'], isFalse);
    expect(row.containsKey('first_name'), isFalse);
    expect(row.containsKey('aadhaar'), isFalse);
    final profile = container.read(ownVerificationProvider);
    expect(profile.isVerified, isFalse);
    expect(profile.publicName, 'Asha Mehta');
    expect(profile.legalFirstName, 'Priya');
  });

  testWidgets('a missing camera stays on the selfie step', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ProfileCreateStore(DemoAccountGateway())
      ..draft = const ProfileCreateDraft(
        step: profileStepSelfie,
        roles: ['tenant'],
        firstName: 'Priya',
        lastName: 'Shah',
        nickname: 'Asha',
        surname: 'Mehta',
        mobileVerified: true,
        emailVerified: true,
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
          profileImageSourceProvider.overrideWithValue(_NoCamera()),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Selfie Verification'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('profile-create-capture')));
    await tester.tap(find.byKey(const Key('profile-create-capture')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-selfie-error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('profile-create-alert-ok')));
    await tester.pumpAndSettle();
    await _continue(tester);
    await tester.tap(find.byKey(const Key('profile-create-alert-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-create-capture')), findsOneWidget);
    expect(store.draft.selfieVerified, isFalse);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _continue(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('profile-create-continue')));
  await tester.tap(find.byKey(const Key('profile-create-continue')));
  await tester.pumpAndSettle();
}
