import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/host/host_onboarding.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/trust/host_trust_panels.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:homizi/features/verification/kyc_providers.dart';
import 'package:homizi/features/verification/offline_kyc_gateway.dart';

void main() {
  Future<void> pump(WidgetTester tester, KycGateway gateway) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [kycGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: HostTrustRecord(
                host: const HostOnboardingDraft(roles: {HostRole.owner}),
                // A local draft flag must not show as verified.
                profile: const ProfileCreateDraft(
                  aadhaarVerified: true,
                  selfieVerified: true,
                ),
                onSubmit: (_) {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
  }

  testWidgets('host trust panel ignores draft flags and offers Get verified', (
    tester,
  ) async {
    await pump(tester, OfflineKycGateway());
    expect(find.text('Aadhaar Verified — not yet'), findsOneWidget);
    expect(find.text('Face Verified — not yet'), findsOneWidget);
    expect(find.byKey(const Key('host-get-verified')), findsOneWidget);
  });

  testWidgets('host trust panel shows the server result', (tester) async {
    await pump(tester, _VerifiedGateway());
    expect(find.text('Aadhaar Verified — not yet'), findsNothing);
    expect(find.text('Face Verified — not yet'), findsNothing);
    expect(find.text('Face Verified'), findsOneWidget);
    expect(find.byKey(const Key('host-get-verified')), findsNothing);
  });
}

class _VerifiedGateway implements KycGateway {
  @override
  Future<bool> available() async => true;

  @override
  Future<KycSnapshot> current() async => const KycSnapshot(
    status: 'verified',
    aadhaarStatus: KycCheckState.verified,
    faceStatus: KycCheckState.verified,
    maskedLast4: '4821',
    message: '',
  );

  @override
  Future<KycSnapshot> giveConsent(KycDocumentKind kind) => current();

  @override
  Future<KycSnapshot> start(KycDocumentKind kind, {String? returnUrl}) =>
      current();

  @override
  Future<KycSnapshot> deleteMine() async => KycSnapshot.notStarted;
}
