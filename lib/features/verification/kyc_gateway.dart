import 'package:homizi/features/verification/domain/kyc_rules.dart';

abstract interface class KycGateway {
  /// True only when the server has every Digio secret. Until then the app
  /// shows "Verification coming soon" and collects nothing.
  Future<bool> available();

  Future<KycSnapshot> current();

  /// Records consent only. It cannot mark the account verified.
  Future<KycSnapshot> giveConsent(KycDocumentKind kind);

  /// Asks the server to open Digio. The server never marks a pass from the app.
  /// [returnUrl] is a request only: the server keeps it when it is on its
  /// allowlist and otherwise sends people back to the live app.
  Future<KycSnapshot> start(KycDocumentKind kind, {String? returnUrl});

  /// Deletes this account's verification row. It cannot mark anyone verified.
  Future<KycSnapshot> deleteMine();
}

class KycFailure implements Exception {
  const KycFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
