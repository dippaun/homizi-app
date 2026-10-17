import 'package:homizi/features/verification/domain/kyc_rules.dart';

abstract interface class KycGateway {
  Future<KycSnapshot> current();

  /// Records consent only. It cannot mark the account verified.
  Future<KycSnapshot> giveConsent(KycDocumentKind kind);

  /// Asks the server to open Digio. The server never marks a pass from the app.
  Future<KycSnapshot> start(KycDocumentKind kind);

  /// Deletes this account's verification row. It cannot mark anyone verified.
  Future<KycSnapshot> deleteMine();
}

class KycFailure implements Exception {
  const KycFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
