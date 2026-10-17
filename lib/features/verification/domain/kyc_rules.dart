enum KycDocumentKind { digilocker, aadhaarOffline, pan }

enum KycCheckState { notStarted, inProgress, verified, failed }

KycDocumentKind? kycKindFromWire(String? value) {
  return switch (value) {
    'digilocker' => KycDocumentKind.digilocker,
    'aadhaar_offline' => KycDocumentKind.aadhaarOffline,
    'pan' => KycDocumentKind.pan,
    _ => null,
  };
}

KycCheckState kycCheckStateFromWire(String? value) {
  return switch (value) {
    'in_progress' || 'pending' => KycCheckState.inProgress,
    'verified' => KycCheckState.verified,
    'failed' || 'rejected' => KycCheckState.failed,
    _ => KycCheckState.notStarted,
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

extension KycCheckStateLabel on KycCheckState {
  String get wire => switch (this) {
    KycCheckState.notStarted => 'not_started',
    KycCheckState.inProgress => 'in_progress',
    KycCheckState.verified => 'verified',
    KycCheckState.failed => 'failed',
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

String aadhaarStatusLabel(KycCheckState state) {
  return switch (state) {
    KycCheckState.notStarted => 'Aadhaar not started',
    KycCheckState.inProgress => 'Aadhaar in progress',
    KycCheckState.verified => 'Aadhaar verified',
    KycCheckState.failed => 'Aadhaar could not be verified',
  };
}

String faceStatusLabel(KycCheckState state) {
  return switch (state) {
    KycCheckState.notStarted => 'Face not started',
    KycCheckState.inProgress => 'Face in progress',
    KycCheckState.verified => 'Face verified',
    KycCheckState.failed => 'Face could not be verified',
  };
}

class KycSnapshot {
  const KycSnapshot({
    required this.status,
    required this.aadhaarStatus,
    required this.faceStatus,
    required this.message,
    this.documentKind,
    this.providerReference,
    this.maskedLast4,
    this.gatewayUrl,
    this.unavailable = false,
  });

  final String status;
  final KycCheckState aadhaarStatus;
  final KycCheckState faceStatus;
  final String message;
  final String? documentKind;
  final String? providerReference;
  final String? maskedLast4;
  final String? gatewayUrl;
  final bool unavailable;

  bool get aadhaarVerified => aadhaarStatus == KycCheckState.verified;

  bool get faceVerified => faceStatus == KycCheckState.verified;

  bool get isVerified => aadhaarVerified && faceVerified;

  bool get canRetry =>
      aadhaarStatus == KycCheckState.failed ||
      faceStatus == KycCheckState.failed;

  static const notStarted = KycSnapshot(
    status: 'not_started',
    aadhaarStatus: KycCheckState.notStarted,
    faceStatus: KycCheckState.notStarted,
    message: 'No identity check has been started.',
  );

  static const comingSoon = KycSnapshot(
    status: 'not_started',
    aadhaarStatus: KycCheckState.notStarted,
    faceStatus: KycCheckState.notStarted,
    unavailable: true,
    message: 'Verification is coming soon.',
  );
}

const kycConsentCopy =
    'HOMIZI asks Digio to verify your Aadhaar and to match a live selfie with the photo on that Aadhaar. The purpose is to show an Aadhaar verified badge and a Face verified badge to people you meet on HOMIZI. Digio collects the Aadhaar check, through DigiLocker or offline e-KYC, and the face scan. HOMIZI stores only the result, the time, the Digio request id, and the last 4 digits. HOMIZI does not store the full Aadhaar number, the document, or the face image. You can delete that record on this screen. This consent is for identity verification under the Digital Personal Data Protection Act, 2023.';

const kycConsentCheckbox =
    'I consent to Aadhaar verification and a face scan for this purpose.';

const kycFaceStepCopy =
    'Digio will open a secure check. You confirm Aadhaar through DigiLocker or offline e-KYC, then take a selfie. Digio checks that the selfie is live and that the face matches the Aadhaar photo. HOMIZI does not keep the photo.';

const kycComingSoonCopy =
    'Verification is coming soon. Your Aadhaar and face badges stay unverified.';

const kycDeleteCopy =
    'Delete the status, the time, the request id, and the last 4 digits stored by HOMIZI.';
