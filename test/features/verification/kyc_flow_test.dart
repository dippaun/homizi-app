import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_launcher.dart';
import 'package:homizi/features/verification/kyc_providers.dart';
import 'package:homizi/features/verification/kyc_screen.dart';
import 'package:homizi/features/verification/offline_kyc_gateway.dart';

final _now = DateTime.utc(2026, 11, 14, 12);

void main() {
  group('rules', () {
    test('an offline check never marks anyone verified', () async {
      final gateway = OfflineKycGateway();
      expect(await gateway.available(), isFalse);
      await gateway.giveConsent(KycDocumentKind.digilocker);
      final started = await gateway.start(KycDocumentKind.digilocker);
      expect(started, KycSnapshot.comingSoon);
      expect(started.unavailable, isTrue);
      expect(started.aadhaarVerified, isFalse);
      expect(started.faceVerified, isFalse);
      expect(started.maskedLast4, isNull);
    });

    test('the stage comes from the server record', () {
      KycStage stage(KycSnapshot s, {bool available = true}) =>
          kycStageFor(s, available: available, now: _now);
      expect(
        stage(KycSnapshot.notStarted, available: false),
        KycStage.comingSoon,
      );
      expect(stage(KycSnapshot.comingSoon), KycStage.comingSoon);
      expect(stage(KycSnapshot.notStarted), KycStage.start);
      expect(stage(_inProgress), KycStage.pending);
      expect(stage(_failed), KycStage.failed);
      expect(stage(_verified), KycStage.verified);
      // A finished pass still shows even if the service is later switched off.
      expect(stage(_verified, available: false), KycStage.verified);
      expect(stage(_staleProgress), KycStage.expired);
      expect(
        _staleProgress.isExpired(_now.subtract(const Duration(days: 2))),
        isFalse,
      );
    });

    test('the return address follows the base href and hash route', () {
      expect(
        kycReturnUrlFor(
          Uri.parse('https://dippaun.github.io/homizi-app/#/verify'),
          web: true,
        ),
        'https://dippaun.github.io/homizi-app/#/verify',
      );
      expect(
        kycReturnUrlFor(
          Uri.parse('https://dippaun.github.io/homizi-app/index.html'),
          web: true,
        ),
        'https://dippaun.github.io/homizi-app/#/verify',
      );
      expect(
        kycReturnUrlFor(Uri.parse('http://localhost:8765/'), web: true),
        'http://localhost:8765/#/verify',
      );
      expect(
        kycReturnUrlFor(Uri.parse('http://evil.example/'), web: true),
        'in.homizi.app://verify',
      );
      expect(
        kycReturnUrlFor(Uri.parse('https://x.example/'), web: false),
        'in.homizi.app://verify',
      );
    });

    test('the gateway address stays https and keeps the server redirect', () {
      const fromServer =
          'https://app.digio.in/#/gateway/login/KID/meera%40example.in/GWT?redirect_url=https%3A%2F%2Fdippaun.github.io%2Fhomizi-app%2F%23%2Fverify';
      final kept = kycGatewayUri(
        fromServer,
        returnUrl: 'https://other.example/#/verify',
      );
      expect(kept.toString(), fromServer);
      final added = kycGatewayUri(
        'https://app.digio.in/#/gateway/login/KID/meera%40example.in/GWT',
        returnUrl: 'https://dippaun.github.io/homizi-app/#/verify',
      );
      expect(added!.scheme, 'https');
      expect(added.toString(), contains('redirect_url='));
      expect(added.toString().toLowerCase(), isNot(contains('sandbox')));
      expect(
        kycGatewayUri('http://app.digio.in/login', returnUrl: '/verify'),
        isNull,
      );
    });

    test('verification copy does not name a non-live mode', () {
      final samples = [
        kycConsentCopy,
        kycConsentCheckbox,
        kycFaceStepCopy,
        kycComingSoonCopy,
        kycComingSoonDetail,
        kycDeleteCopy,
        kycDigilockerCopy,
        kycOfflineCopy,
        kycPendingCopy,
        kycExpiredCopy,
        kycSuccessCopy,
        ...kycPrivacyNotes,
      ];
      for (final sample in samples) {
        final lower = sample.toLowerCase();
        expect(lower.contains('sandbox'), isFalse, reason: sample);
        expect(lower.contains('demo'), isFalse, reason: sample);
        expect(lower.contains('mock'), isFalse, reason: sample);
        expect(RegExp(r'\btest\b').hasMatch(lower), isFalse, reason: sample);
      }
    });
  });

  group('screen', () {
    testWidgets(
      'without Digio secrets it shows coming soon and collects nothing',
      (tester) async {
        await _pump(tester);
        expect(find.byKey(const Key('kyc-coming-soon')), findsOneWidget);
        expect(find.text('Verification coming soon'), findsOneWidget);
        expect(find.byKey(const Key('kyc-consent-copy')), findsNothing);
        expect(find.byKey(const Key('kyc-get-started')), findsNothing);
        expect(find.text('Aadhaar verified'), findsNothing);
        expect(find.byType(BackButton), findsOneWidget);
      },
    );

    testWidgets('intro, method, consent, face step, then pending and success', (
      tester,
    ) async {
      final gateway = _ScriptedKycGateway();
      final launcher = _RecordingLauncher();
      await _pump(tester, gateway: gateway, launcher: launcher);

      expect(find.byKey(const Key('kyc-intro')), findsOneWidget);
      expect(find.byKey(const Key('kyc-privacy')), findsOneWidget);
      await _tap(tester, 'kyc-get-started');

      expect(find.byKey(const Key('kyc-method-digilocker')), findsOneWidget);
      await _tap(tester, 'kyc-method-offline');
      await _tap(tester, 'kyc-method-next');

      expect(find.byKey(const Key('kyc-consent-copy')), findsOneWidget);
      // Continue stays off until the box is ticked.
      await _tap(tester, 'kyc-continue');
      expect(find.byKey(const Key('kyc-face-step')), findsNothing);
      await _tap(tester, 'kyc-consent');
      await _tap(tester, 'kyc-continue');

      expect(find.byKey(const Key('kyc-face-step')), findsOneWidget);
      expect(gateway.starts, 0);
      await _tap(tester, 'kyc-open-digio');

      expect(gateway.consentKinds, [KycDocumentKind.aadhaarOffline]);
      expect(gateway.starts, 1);
      expect(gateway.lastReturnUrl, isNotNull);
      expect(launcher.opened, hasLength(1));
      expect(launcher.opened.single.scheme, 'https');
      expect(find.byKey(const Key('kyc-pending')), findsOneWidget);
      expect(find.text('Aadhaar in progress'), findsOneWidget);
      expect(find.text('Face in progress'), findsOneWidget);

      // The webhook lands; the next poll picks it up.
      gateway.stage = _verified;
      await tester.pump(kycPollEvery);
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byKey(const Key('kyc-success')), findsOneWidget);
      expect(find.text('Aadhaar verified'), findsOneWidget);
      expect(find.text('Face verified'), findsOneWidget);
      expect(find.textContaining('4821'), findsOneWidget);
      expect(find.textContaining('123456789012'), findsNothing);
      expect(find.byKey(const Key('kyc-done')), findsOneWidget);
    });

    testWidgets('pending can be checked by hand and reopened', (tester) async {
      final gateway = _ScriptedKycGateway()..startedOnce = true;
      final launcher = _RecordingLauncher();
      await _pump(tester, gateway: gateway, launcher: launcher);
      expect(find.byKey(const Key('kyc-pending')), findsOneWidget);
      expect(find.byKey(const Key('kyc-refresh')), findsOneWidget);
      gateway.stage = _failed;
      await _tap(tester, 'kyc-refresh');
      expect(find.byKey(const Key('kyc-failed')), findsOneWidget);
    });

    testWidgets('a failure offers a retry that starts again', (tester) async {
      final gateway = _ScriptedKycGateway()
        ..startedOnce = true
        ..stage = _failed;
      await _pump(tester, gateway: gateway);
      expect(find.byKey(const Key('kyc-failed')), findsOneWidget);
      expect(find.text('Aadhaar could not be verified'), findsOneWidget);
      await _tap(tester, 'kyc-retry');
      expect(find.byKey(const Key('kyc-method-digilocker')), findsOneWidget);
      await _tap(tester, 'kyc-method-next');
      await _tap(tester, 'kyc-consent');
      await _tap(tester, 'kyc-continue');
      gateway.stage = _inProgress;
      await _tap(tester, 'kyc-open-digio');
      expect(gateway.starts, 1);
      expect(find.byKey(const Key('kyc-pending')), findsOneWidget);
    });

    testWidgets('a link older than 10 days shows expired with a retry', (
      tester,
    ) async {
      final gateway = _ScriptedKycGateway()
        ..startedOnce = true
        ..stage = _staleProgress;
      await _pump(tester, gateway: gateway);
      expect(find.byKey(const Key('kyc-expired')), findsOneWidget);
      expect(find.byKey(const Key('kyc-retry')), findsOneWidget);
    });

    testWidgets('a Digio error keeps the person on the step with a message', (
      tester,
    ) async {
      final gateway = _ScriptedKycGateway()
        ..startError = const KycFailure(
          'Digio could not open the check just now.',
        );
      await _pump(tester, gateway: gateway);
      await _tap(tester, 'kyc-get-started');
      await _tap(tester, 'kyc-method-next');
      await _tap(tester, 'kyc-consent');
      await _tap(tester, 'kyc-continue');
      await _tap(tester, 'kyc-open-digio');
      expect(find.byKey(const Key('kyc-error')), findsOneWidget);
      expect(find.byKey(const Key('kyc-face-step')), findsOneWidget);
    });

    testWidgets('the server closing mid-flow falls back to coming soon', (
      tester,
    ) async {
      final gateway = _ScriptedKycGateway()
        ..startResult = KycSnapshot.comingSoon;
      await _pump(tester, gateway: gateway);
      await _tap(tester, 'kyc-get-started');
      await _tap(tester, 'kyc-method-next');
      await _tap(tester, 'kyc-consent');
      await _tap(tester, 'kyc-continue');
      await _tap(tester, 'kyc-open-digio');
      expect(find.byKey(const Key('kyc-coming-soon')), findsOneWidget);
    });

    testWidgets('one back control walks back through the steps', (
      tester,
    ) async {
      await _pump(tester, gateway: _ScriptedKycGateway());
      await _tap(tester, 'kyc-get-started');
      await _tap(tester, 'kyc-method-next');
      expect(find.byKey(const Key('kyc-consent-copy')), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pump();
      expect(find.byKey(const Key('kyc-method-digilocker')), findsOneWidget);
    });

    testWidgets('deleting a verified record returns to the start', (
      tester,
    ) async {
      final gateway = _ScriptedKycGateway()
        ..startedOnce = true
        ..stage = _verified;
      await _pump(tester, gateway: gateway);
      expect(find.byKey(const Key('kyc-success')), findsOneWidget);
      await _tap(tester, 'kyc-delete');
      await _tap(tester, 'kyc-delete-confirm');
      expect(gateway.deleted, isTrue);
      expect(find.byKey(const Key('kyc-intro')), findsOneWidget);
      expect(find.text('Verification data deleted.'), findsOneWidget);
    });
  });

  testWidgets('identity badges are green and come only from the server', (
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
    final chip = tester.widget<Chip>(
      find.ancestor(
        of: find.text('Aadhaar verified').first,
        matching: find.byType(Chip),
      ),
    );
    expect(chip.backgroundColor, HomiziColors.successWash);
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
      'https://app.digio.in/#/gateway/login/KID/meera%40example.in/GWT?redirect_url=https%3A%2F%2Fdippaun.github.io%2Fhomizi-app%2F%23%2Fverify',
  message: 'Verification is in progress.',
);

final _staleProgress = KycSnapshot(
  status: 'pending',
  aadhaarStatus: KycCheckState.inProgress,
  faceStatus: KycCheckState.inProgress,
  message: 'Verification is in progress.',
  startedAt: _now.subtract(const Duration(days: 11)),
);

class _ScriptedKycGateway implements KycGateway {
  var isAvailable = true;
  KycSnapshot stage = _inProgress;
  KycSnapshot? startResult;
  KycFailure? startError;
  var startedOnce = false;
  var starts = 0;
  var deleted = false;
  String? lastReturnUrl;
  final consentKinds = <KycDocumentKind>[];

  @override
  Future<bool> available() async => isAvailable;

  @override
  Future<KycSnapshot> current() async {
    if (!startedOnce) {
      return KycSnapshot.notStarted;
    }
    return stage;
  }

  @override
  Future<KycSnapshot> giveConsent(KycDocumentKind kind) async {
    consentKinds.add(kind);
    return const KycSnapshot(
      status: 'consent_given',
      aadhaarStatus: KycCheckState.notStarted,
      faceStatus: KycCheckState.notStarted,
      message: kycConsentCopy,
    );
  }

  @override
  Future<KycSnapshot> start(KycDocumentKind kind, {String? returnUrl}) async {
    final error = startError;
    if (error != null) {
      throw error;
    }
    if (consentKinds.isEmpty) {
      throw const KycFailure('Consent is required before verification.');
    }
    starts += 1;
    startedOnce = true;
    lastReturnUrl = returnUrl;
    return startResult ?? stage;
  }

  @override
  Future<KycSnapshot> deleteMine() async {
    deleted = true;
    startedOnce = false;
    consentKinds.clear();
    return KycSnapshot.notStarted;
  }
}

class _RecordingLauncher implements KycLauncher {
  final opened = <Uri>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

Future<void> _pump(
  WidgetTester tester, {
  KycGateway? gateway,
  KycLauncher? launcher,
}) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (gateway != null) kycGatewayProvider.overrideWithValue(gateway),
        kycLauncherProvider.overrideWithValue(launcher ?? _RecordingLauncher()),
      ],
      child: MaterialApp(
        theme: HomiziTheme.light(),
        home: KycScreen(now: () => _now),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}
