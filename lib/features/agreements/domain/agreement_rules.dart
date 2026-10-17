enum AgreementStatus {
  draft,
  sent,
  tenantSigned,
  ownerSigned,
  completed,
  declined,
  expired,
}

AgreementStatus agreementStatusFromWire(String? value) {
  return switch (value) {
    'sent' => AgreementStatus.sent,
    'tenant_signed' => AgreementStatus.tenantSigned,
    'owner_signed' => AgreementStatus.ownerSigned,
    'completed' => AgreementStatus.completed,
    'declined' => AgreementStatus.declined,
    'expired' => AgreementStatus.expired,
    _ => AgreementStatus.draft,
  };
}

extension AgreementStatusWire on AgreementStatus {
  String get wire => switch (this) {
    AgreementStatus.draft => 'draft',
    AgreementStatus.sent => 'sent',
    AgreementStatus.tenantSigned => 'tenant_signed',
    AgreementStatus.ownerSigned => 'owner_signed',
    AgreementStatus.completed => 'completed',
    AgreementStatus.declined => 'declined',
    AgreementStatus.expired => 'expired',
  };

  String get label => switch (this) {
    AgreementStatus.draft => 'Draft',
    AgreementStatus.sent => 'Sent for signature',
    AgreementStatus.tenantSigned => 'Tenant signed',
    AgreementStatus.ownerSigned => 'Owner signed',
    AgreementStatus.completed => 'Completed',
    AgreementStatus.declined => 'Declined',
    AgreementStatus.expired => 'Expired',
  };
}

/// Next demo status after one party signs. Null when the provider must do it,
/// or when this party has already signed.
AgreementStatus? demoStatusAfterSign({
  required AgreementStatus current,
  required String role,
  required String provider,
}) {
  if (provider != 'demo') {
    return null;
  }
  final signer = role.trim().toLowerCase();
  if (signer != 'tenant' && signer != 'owner') {
    return null;
  }
  return switch ((current, signer)) {
    (AgreementStatus.sent, 'tenant') => AgreementStatus.tenantSigned,
    (AgreementStatus.sent, 'owner') => AgreementStatus.ownerSigned,
    (AgreementStatus.tenantSigned, 'owner') => AgreementStatus.completed,
    (AgreementStatus.ownerSigned, 'tenant') => AgreementStatus.completed,
    _ => null,
  };
}

String? validateAgreementDraft({
  required String title,
  required String body,
  required int? rentInr,
  required int? termMonths,
}) {
  final name = title.trim();
  if (name.length < 3 || name.length > 120) {
    return 'Enter a title between 3 and 120 characters.';
  }
  if (name.contains('@') || body.contains('@')) {
    return 'Leave email addresses out of the draft.';
  }
  if (RegExp(r'\d{12}').hasMatch(body) || RegExp(r'\d{12}').hasMatch(name)) {
    return 'Do not put an identity number in the draft.';
  }
  if (rentInr == null || rentInr < 1) {
    return 'Enter the monthly rent in whole rupees.';
  }
  if (termMonths == null || termMonths < 1 || termMonths > 60) {
    return 'Enter a term between 1 and 60 months.';
  }
  return null;
}

String agreementDraftBody({
  required String title,
  required int rentInr,
  required int depositInr,
  required int termMonths,
}) {
  return 'Leave and licence draft for $title. '
      'Monthly rent INR $rentInr. Deposit INR $depositInr. '
      'Term $termMonths months. '
      'This text is a draft for e-sign. It is not stamped or registered.';
}

class AgreementRecord {
  const AgreementRecord({
    required this.id,
    required this.title,
    required this.status,
    required this.provider,
    required this.tenantName,
    required this.ownerName,
    this.providerReference,
    this.stampAmountInr,
    this.sourceDraftId,
    this.body = '',
  });

  final String id;
  final String title;
  final AgreementStatus status;
  final String provider;
  final String tenantName;
  final String ownerName;
  final String? providerReference;
  final int? stampAmountInr;
  final String? sourceDraftId;
  final String body;

  bool get isDemo => provider == 'demo';
}
