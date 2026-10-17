import 'package:homizi/features/verification/domain/kyc_rules.dart';

abstract interface class KycGateway {
  Future<KycSnapshot> current();

  /// Records consent only. It cannot mark the account verified.
  Future<KycSnapshot> giveConsent(KycDocumentKind kind);

  /// Demo sandbox, or the edge function when Supabase is connected.
  Future<KycSnapshot> startSandbox(KycDocumentKind kind);
}

class KycFailure implements Exception {
  const KycFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
