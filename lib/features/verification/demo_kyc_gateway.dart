import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';

/// Demo check. No number, image, or document is accepted or stored.
class DemoKycGateway implements KycGateway {
  KycSnapshot _snapshot = KycSnapshot.notStarted;

  @override
  Future<KycSnapshot> current() async => _snapshot;

  @override
  Future<KycSnapshot> giveConsent(KycDocumentKind kind) async {
    _snapshot = KycSnapshot(
      status: 'consent_given',
      provider: 'demo',
      documentKind: kind.wire,
      message: kycConsentCopy,
    );
    return _snapshot;
  }

  @override
  Future<KycSnapshot> startSandbox(KycDocumentKind kind) async {
    if (_snapshot.status == 'not_started') {
      throw const KycFailure('Consent is required before a sandbox check.');
    }
    _snapshot = KycSnapshot(
      status: 'verified',
      provider: 'demo',
      documentKind: kind.wire,
      providerReference: 'demo-kyc',
      maskedLast4: '4821',
      message: 'Verified (demo). No Aadhaar number or document was collected.',
    );
    return _snapshot;
  }
}
