import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';

/// Used when no project is connected. It never marks a check verified.
class OfflineKycGateway implements KycGateway {
  KycSnapshot _snapshot = KycSnapshot.notStarted;

  @override
  Future<KycSnapshot> current() async => _snapshot;

  @override
  Future<KycSnapshot> giveConsent(KycDocumentKind kind) async {
    _snapshot = KycSnapshot(
      status: 'consent_given',
      aadhaarStatus: KycCheckState.notStarted,
      faceStatus: KycCheckState.notStarted,
      documentKind: kind.wire,
      message: kycConsentCopy,
    );
    return _snapshot;
  }

  @override
  Future<KycSnapshot> start(KycDocumentKind kind) async {
    if (_snapshot.status == 'not_started') {
      throw const KycFailure('Consent is required before verification.');
    }
    return KycSnapshot.comingSoon;
  }

  @override
  Future<KycSnapshot> deleteMine() async {
    _snapshot = KycSnapshot.notStarted;
    return _snapshot;
  }
}
