import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/broker_flow/broker_flow_screen.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';

const _demoConfig = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

void main() {
  testWidgets('broker flow walks onboarding, listing, desk, and confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(_demoConfig)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const BrokerFlowScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.byKey(const Key('broker-flow-profile')), findsOneWidget);
    expect(find.byKey(const Key('broker-flow-agency')), findsOneWidget);
    expect(find.byKey(const Key('broker-flow-rera')), findsOneWidget);
    expect(find.text('RERA number (optional)'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.byKey(const Key('broker-flow-verify')), findsOneWidget);
    _oneBack();

    await _tap(tester, const Key('broker-send-mobile'));
    await tester.enterText(
      find.byKey(const Key('broker-mobile-otp')),
      '000000',
    );
    await _tap(tester, const Key('broker-verify-mobile'));
    await _tap(tester, const Key('broker-send-email'));
    await tester.enterText(find.byKey(const Key('broker-email-otp')), '000000');
    await _tap(tester, const Key('broker-verify-email'));
    await _tap(tester, const Key('broker-open-digio'));
    expect(find.text('Aadhaar verified'), findsNothing);
    expect(find.byKey(const Key('broker-aadhaar-state')), findsOneWidget);
    final aadhaar = tester.widget<Text>(
      find.byKey(const Key('broker-aadhaar-state')),
    );
    expect(aadhaar.data, isNot(aadhaarStatusLabel(KycCheckState.verified)));

    await _continue(tester);
    expect(find.byKey(const Key('broker-trust-badge')), findsOneWidget);
    expect(find.text('Mobile verified'), findsOneWidget);
    expect(find.text('Email verified'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.byKey(const Key('broker-onboard-confirm')), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.text('List Your Property'), findsOneWidget);
    expect(find.text('in Just a Few Steps'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.byKey(const Key('broker-flow-intent')), findsOneWidget);
    expect(find.text('1/8'), findsOneWidget);
    expect(find.text('Start Listing Your Property'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.text('2/8'), findsOneWidget);
    expect(find.text('Add Property Location'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.text('3/8'), findsOneWidget);
    expect(find.text('Nearby Places (Auto-detected)'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.text('4/8'), findsOneWidget);
    expect(find.text('Property & Living Details'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.text('5/8'), findsOneWidget);
    expect(find.text('House Rules & Tenant Preference'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.text('6/8'), findsOneWidget);
    expect(find.text('Services, Flatmates & Availability'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.text('7/8'), findsOneWidget);
    expect(find.text('Rent & Charges'), findsOneWidget);
    expect(find.byKey(const Key('broker-brokerage')), findsOneWidget);
    expect(find.text('Brokerage fee (₹)'), findsOneWidget);
    expect(find.byKey(const Key('broker-owner-auth')), findsOneWidget);
    await _tap(tester, const Key('broker-owner-auth-toggle'));
    await _tap(tester, const Key('broker-owner-auth-upload'));
    expect(find.text('owner-authorisation.pdf'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.text('8/8'), findsOneWidget);
    expect(find.text('Upload Property Photos'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.byKey(const Key('broker-flow-review')), findsOneWidget);
    expect(find.text('Review & Publish'), findsOneWidget);
    expect(find.byKey(const Key('broker-listed-badge')), findsOneWidget);
    expect(find.text('Listed by Broker'), findsWidgets);
    _oneBack();

    await _tap(tester, const Key('broker-flow-publish'));
    expect(find.byKey(const Key('broker-published-confirm')), findsOneWidget);
    expect(find.text('Listing saved'), findsOneWidget);
    _oneBack();

    await _continue(tester);
    expect(find.byKey(const Key('broker-desk')), findsOneWidget);
    expect(find.textContaining('% match'), findsWidgets);
    _oneBack();

    await _continue(tester);
    expect(find.byKey(const Key('broker-flow-confirmation')), findsOneWidget);
    expect(find.text('You\'re all set'), findsOneWidget);
    _oneBack();

    await _tap(tester, const Key('broker-flow-back'));
    expect(find.byKey(const Key('broker-desk')), findsOneWidget);
  });

  testWidgets('broker mode on the shared wizard adds authorisation and badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(_demoConfig)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const ListingEditorScreen(fresh: true, brokerMode: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(BackButton), findsOneWidget);
    for (var step = 0; step < 6; step++) {
      await tester.ensureVisible(find.byKey(const Key('listing-continue')));
      await tester.tap(find.byKey(const Key('listing-continue')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('7/8'), findsOneWidget);
    expect(find.byKey(const Key('broker-owner-auth')), findsOneWidget);
    expect(find.byKey(const Key('listing-charges')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('listing-continue')));
    await tester.tap(find.byKey(const Key('listing-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('8/8'), findsOneWidget);
    expect(find.byKey(const Key('broker-listed-badge')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });
}

void _oneBack() {
  expect(find.byType(HomiziBackButton), findsOneWidget);
  expect(find.byType(BackButton), findsOneWidget);
}

Future<void> _continue(WidgetTester tester) =>
    _tap(tester, const Key('broker-flow-continue'));

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 30));
  final error = find.byKey(const Key('broker-flow-error'));
  if (error.evaluate().isNotEmpty) {
    final text = tester.widget<Text>(error).data;
    fail(text ?? 'broker flow error');
  }
}
