enum KycDocumentKind { digilocker, aadhaarOffline, pan }

KycDocumentKind? kycKindFromWire(String? value) {
  return switch (value) {
    'digilocker' => KycDocumentKind.digilocker,
    'aadhaar_offline' => KycDocumentKind.aadhaarOffline,
    'pan' => KycDocumentKind.pan,
    _ => null,
  };
}

extension KycDocumentKindWire on KycDocumentKind {
  String get wire => switch (this) {
    KycDocumentKind.digilocker => 'digilocker',
    KycDocumentKind.aadhaarOffline => 'aadhaar_offline',
    KycDocumentKind.pan => 'pan',
  };

  String get label => switch (this) {
    KycDocumentKind.digilocker => 'DigiLocker',
    KycDocumentKind.aadhaarOffline => 'Aadhaar offline',
    KycDocumentKind.pan => 'PAN',
  };
}

/// A 12-digit run is treated as an Aadhaar number and must not be stored.
bool looksLikeRawAadhaar(String value) {
  final digits = value.replaceAll(RegExp(r'\s|-'), '');
  return RegExp(r'^\d{12}$').hasMatch(digits) ||
      RegExp(r'\d{12}').hasMatch(value);
}

/// Last 4 characters only. A full Aadhaar number is refused, not trimmed.
String? maskedLast4OrNull(String value) {
  final compact = value.trim().toUpperCase();
  if (looksLikeRawAadhaar(compact)) {
    return null;
  }
  if (!RegExp(r'^[0-9A-Z]{4}$').hasMatch(compact)) {
    return null;
  }
  return compact;
}

class KycSnapshot {
  const KycSnapshot({
    required this.status,
    required this.provider,
    required this.message,
    this.documentKind,
    this.providerReference,
    this.maskedLast4,
  });

  final String status;
  final String provider;
  final String message;
  final String? documentKind;
  final String? providerReference;
  final String? maskedLast4;

  bool get isVerified => status == 'verified';

  static const notStarted = KycSnapshot(
    status: 'not_started',
    provider: 'demo',
    message: 'No identity check has been started.',
  );
}

const kycConsentCopy =
    'HOMIZI stores a status, a provider reference, and the last 4 characters only. An Aadhaar number or a document image is never stored.';
