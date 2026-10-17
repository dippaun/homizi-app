import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_launcher.dart';
import 'package:homizi/features/verification/kyc_providers.dart';
import 'package:homizi/features/verification/kyc_screen.dart';
import 'package:homizi/features/verification/offline_kyc_gateway.dart';

void main() {
  test('an offline check never marks anyone verified', () async {
    final gateway = OfflineKycGateway();
    await gateway.giveConsent(KycDocumentKind.digilocker);
    final started = await gateway.start(KycDocumentKind.digilocker);
    expect(started, KycSnapshot.comingSoon);
    expect(started.unavailable, isTrue);
    expect(started.aadhaarVerified, isFalse);
    expect(started.faceVerified, isFalse);
    expect(started.maskedLast4, isNull);
  });

  test('verification copy does not name a non-live mode', () {
    const samples = [
      kycConsentCopy,
      kycConsentCheckbox,
      kycFaceStepCopy,
      kycComingSoonCopy,
      kycDeleteCopy,
      'Aadhaar verified',
      'Face verified',
      'Verification is coming soon.',
    ];
    for (final sample in samples) {
      final lower = sample.toLowerCase();
      expect(lower.contains('sandbox'), isFalse, reason: sample);
      expect(lower.contains('demo'), isFalse, reason: sample);
      expect(lower.contains('mock'), isFalse, reason: sample);
      expect(RegExp(r'\btest\b').hasMatch(lower), isFalse, reason: sample);
    }
  });

  test('the gateway address stays https and does not add a mode', () {
    final uri = kycGatewayUri(
      'https://app.digio.in/#/gateway/login/KID/meera%40example.test/GWT',
      returnUrl: 'https://homizi.netlify.app/verify',
    );
    expect(uri, isNotNull);
    expect(uri!.scheme, 'https');
    expect(uri.toString(), contains('redirect_url='));
    expect(uri.toString().toLowerCase(), isNot(contains('sandbox')));
    expect(uri.toString().toLowerCase(), isNot(contains('mode=')));
    expect(
      kycGatewayUri('http://app.digio.in/login', returnUrl: '/verify'),
      isNull,
    );
  });

  testWidgets('consent then an unconfigured server stays unverified', (
    tester,
  ) async {
    await _pump(tester, const KycScreen());
    expect(find.byKey(const Key('kyc-consent-copy')), findsOneWidget);
    expect(find.textContaining('sandbox'), findsNothing);
    expect(find.textContaining('demo'), findsNothing);
    await tester.tap(find.byKey(const Key('kyc-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('kyc-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('kyc-coming-soon')), findsOneWidget);
    expect(find.text('Aadhaar verified'), findsNothing);
    expect(find.text('Face verified'), findsNothing);
    expect(find.textContaining('123456789012'), findsNothing);
    expect(find.byKey(const Key('kyc-mask')), findsNothing);
  });

  testWidgets('a server result shows both badges, a failure can be retried', (
    tester,
  ) async {
    final gateway = _ScriptedKycGateway();
    await _pump(tester, const KycScreen(), gateway: gateway);
    await tester.tap(find.byKey(const Key('kyc-consent')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('kyc-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('kyc-face-step')), findsOneWidget);
    expect(find.text('Aadhaar in progress'), findsOneWidget);
    expect(find.text('Face in progress'), findsOneWidget);
    expect(gateway.starts, 1);

    gateway.stage = _verified;
    await tester.tap(find.byKey(const Key('kyc-refresh')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Aadhaar verified'), findsOneWidget);
    expect(find.text('Face verified'), findsOneWidget);
    expect(find.byKey(const Key('kyc-mask')), findsOneWidget);
    expect(find.textContaining('4821'), findsOneWidget);
    expect(find.textContaining('123456789012'), findsNothing);

    gateway.stage = _failed;
    await tester.tap(find.byKey(const Key('kyc-delete')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.tap(find.byKey(const Key('kyc-delete-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('kyc-consent-copy')), findsOneWidget);

    await tester.tap(find.byKey(const Key('kyc-consent')));
    await tester.pump();
    gateway.stage = _failed;
    await tester.tap(find.byKey(const Key('kyc-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.byKey(const Key('kyc-retry')), findsOneWidget);
    expect(find.text('Aadhaar could not be verified'), findsOneWidget);
    gateway.stage = _verified;
    await tester.tap(find.byKey(const Key('kyc-retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Face verified'), findsOneWidget);
  });

  testWidgets('listing, swipe, and chat surfaces show only server badges', (
    tester,
  ) async {
    const verified = UserBadges(aadhaarVerified: true, faceVerified: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: HomiziTheme.light(),
        home: Scaffold(
          body: ListView(
            children: const [
              TrustBadgeRow(badges: verified),
              IdentityBadgeRow(badges: verified),
              TrustBadgeRow(
                badges: UserBadges(idVerifiedDemo: true, phoneVerified: true),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Aadhaar verified'), findsWidgets);
    expect(find.text('Face verified'), findsWidgets);
    expect(find.text('Phone verified'), findsOneWidget);
    expect(find.text('ID verified (demo)'), findsNothing);
  });
}

const _verified = KycSnapshot(
  status: 'verified',
  aadhaarStatus: KycCheckState.verified,
  faceStatus: KycCheckState.verified,
  maskedLast4: '4821',
  message: 'Verified. HOMIZI stored the result and the last 4 digits only.',
);

const _failed = KycSnapshot(
  status: 'rejected',
  aadhaarStatus: KycCheckState.failed,
  faceStatus: KycCheckState.failed,
  message: 'Verification did not finish. You can try again.',
);

const _inProgress = KycSnapshot(
  status: 'pending',
  aadhaarStatus: KycCheckState.inProgress,
  faceStatus: KycCheckState.inProgress,
  gatewayUrl:
      'https://app.digio.in/#/gateway/login/KID/meera%40example.test/GWT',
  message: 'Verification is in progress.',
);

class _ScriptedKycGateway implements KycGateway {
  KycSnapshot stage = _inProgress;
  var starts = 0;
  var consented = false;

  @override
  Future<KycSnapshot> current() async {
    if (starts == 0) {
      return KycSnapshot.notStarted;
    }
    return stage;
  }

  @override
  Future<KycSnapshot> giveConsent(KycDocumentKind kind) async {
    consented = true;
    return const KycSnapshot(
      status: 'consent_given',
      aadhaarStatus: KycCheckState.notStarted,
      faceStatus: KycCheckState.notStarted,
      message: kycConsentCopy,
    );
  }

  @override
  Future<KycSnapshot> start(KycDocumentKind kind) async {
    if (!consented) {
      throw const KycFailure('Consent is required before verification.');
    }
    starts += 1;
    return stage;
  }

  @override
  Future<KycSnapshot> deleteMine() async {
    consented = false;
    return KycSnapshot.notStarted;
  }
}

class _QuietLauncher implements KycLauncher {
  @override
  Future<bool> open(Uri uri) async => false;
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  KycGateway? gateway,
}) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (gateway != null) kycGatewayProvider.overrideWithValue(gateway),
        kycLauncherProvider.overrideWithValue(_QuietLauncher()),
      ],
      child: MaterialApp(theme: HomiziTheme.light(), home: child),
    ),
  );
  await tester.pump();
}
