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
    this.startedAt,
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

  /// When start-kyc opened the current Digio request.
  final DateTime? startedAt;

  bool get aadhaarVerified => aadhaarStatus == KycCheckState.verified;

  bool get faceVerified => faceStatus == KycCheckState.verified;

  bool get isVerified => aadhaarVerified && faceVerified;

  bool get isFailed =>
      aadhaarStatus == KycCheckState.failed ||
      faceStatus == KycCheckState.failed;

  bool get isPending =>
      !isVerified &&
      !isFailed &&
      (aadhaarStatus == KycCheckState.inProgress ||
          faceStatus == KycCheckState.inProgress ||
          status == 'pending');

  /// Digio links expire after [kycLinkLifetime]. A request still pending after
  /// that will never finish, so the person can start a new one.
  bool isExpired(DateTime now) {
    final opened = startedAt;
    return isPending &&
        opened != null &&
        now.difference(opened) > kycLinkLifetime;
  }

  bool get canRetry => isFailed;

  KycSnapshot copyWith({
    String? gatewayUrl,
    bool? unavailable,
    String? message,
  }) {
    return KycSnapshot(
      status: status,
      aadhaarStatus: aadhaarStatus,
      faceStatus: faceStatus,
      message: message ?? this.message,
      documentKind: documentKind,
      providerReference: providerReference,
      maskedLast4: maskedLast4,
      gatewayUrl: gatewayUrl ?? this.gatewayUrl,
      unavailable: unavailable ?? this.unavailable,
      startedAt: startedAt,
    );
  }

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

/// Matches expire_in_days in supabase/functions/_shared/kyc.ts.
const kycLinkLifetime = Duration(days: 10);

/// What the KYC screen shows, worked out from the server record.
enum KycStage { comingSoon, start, pending, expired, failed, verified }

KycStage kycStageFor(
  KycSnapshot snapshot, {
  required bool available,
  required DateTime now,
}) {
  if (snapshot.isVerified) {
    return KycStage.verified;
  }
  if (!available || snapshot.unavailable) {
    return KycStage.comingSoon;
  }
  if (snapshot.isFailed) {
    return KycStage.failed;
  }
  if (snapshot.isExpired(now)) {
    return KycStage.expired;
  }
  if (snapshot.isPending) {
    return KycStage.pending;
  }
  return KycStage.start;
}

const kycConsentCopy =
    'HOMIZI asks Digio to verify your Aadhaar and to match a live selfie with the photo on that Aadhaar. The purpose is to show an Aadhaar verified badge and a Face verified badge to people you meet on HOMIZI. Digio collects the Aadhaar check, through DigiLocker or offline e-KYC, and the face scan. HOMIZI stores only the result, the time, the Digio request id, and the last 4 digits. HOMIZI does not store the full Aadhaar number, the document, or the face image. You can delete that record on this screen. This consent is for identity verification under the Digital Personal Data Protection Act, 2023.';

const kycConsentCheckbox =
    'I consent to Aadhaar verification and a face scan for this purpose.';

const kycFaceStepCopy =
    'Digio will open a secure check. You confirm Aadhaar through DigiLocker or offline e-KYC, then take a selfie. Digio checks that the selfie is live and that the face matches the Aadhaar photo. HOMIZI does not keep the photo.';

const kycComingSoonCopy =
    'Verification is coming soon. Your Aadhaar and face badges stay unverified.';

const kycComingSoonDetail =
    'HOMIZI will verify Aadhaar and a live selfie through Digio, a licensed KYC provider. We will show it here as soon as it opens. Nothing about your Aadhaar is collected until then.';

const kycPrivacyNotes = <String>[
  'Digio runs the check. HOMIZI never sees your Aadhaar number, document, or selfie.',
  'HOMIZI keeps only the result, the time, the Digio request id, and the last 4 digits.',
  'You can delete that record from this screen at any time.',
];

const kycDigilockerCopy =
    'Sign in to DigiLocker with your Aadhaar-linked mobile number. Quickest.';

const kycOfflineCopy =
    'Use the Aadhaar Offline XML (paperless e-KYC) from the UIDAI site and its share code.';

const kycPendingCopy =
    'Digio is checking your Aadhaar and selfie. This usually takes under a minute. You can leave this screen; your badges update on their own.';

const kycExpiredCopy =
    'The last verification link expired before it finished. Start a new check.';

const kycSuccessCopy =
    'Your Aadhaar and face are verified. People you meet on HOMIZI now see your verified badges.';

const kycDeleteCopy =
    'Delete the status, the time, the request id, and the last 4 digits stored by HOMIZI.';
