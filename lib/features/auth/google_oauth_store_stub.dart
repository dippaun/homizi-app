String? _policyVersion;

/// Remembers that this sign-in already accepted the terms.
/// The web app stores the same value in sessionStorage so a full reload
/// after Google can still write the consent row.
void rememberGoogleConsent(String policyVersion) {
  final version = policyVersion.trim();
  _policyVersion = version.isEmpty ? null : version;
}

String? peekGoogleConsent() => _policyVersion;

void clearGoogleConsent() {
  _policyVersion = null;
}

String? googleReturnErrorMessage() => null;

void clearGoogleReturnError() {}
