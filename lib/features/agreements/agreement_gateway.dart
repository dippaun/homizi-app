import 'package:homizi/features/agreements/domain/agreement_rules.dart';

abstract interface class AgreementGateway {
  Future<List<AgreementRecord>> listMine();

  Future<AgreementRecord> createDraft({
    required String matchId,
    required String title,
    required String body,
    required String tenantName,
    required String ownerName,
    int? stampAmountInr,
    String? sourceDraftId,
  });

  Future<AgreementRecord> sendForSignature(String id);

  /// Demo provider only. Digio status moves on the webhook.
  Future<AgreementRecord> demoSign(String id, {required String role});
}

class AgreementFailure implements Exception {
  const AgreementFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
