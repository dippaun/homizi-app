/// Client mirror of `public.get_contact_visibility`.
///
/// The database function is authoritative. This helper exists so the UI copy
/// and unit tests describe the same rule: contact fields are returned only
/// when the caller is in an active match, nobody is blocked, and the other
/// person has unrevoked consent for that scope.
enum ContactDenyReason {
  unauthenticated,
  notParticipant,
  matchInactive,
  blocked,
  consentRequired,
}

enum ContactScope { phone, email, phoneAndEmail }

class ContactVisibilityDecision {
  const ContactVisibilityDecision.hidden(this.reason)
    : visible = false,
      phone = null,
      email = null;

  const ContactVisibilityDecision.granted({this.phone, this.email})
    : visible = true,
      reason = null;

  final bool visible;
  final ContactDenyReason? reason;
  final String? phone;
  final String? email;
}

ContactVisibilityDecision evaluateContactVisibility({
  required String? callerId,
  required String participantA,
  required String participantB,
  required bool matchActive,
  required bool blocked,
  required bool otherConsented,
  required ContactScope? consentScope,
  required String? otherPhone,
  required String? otherEmail,
}) {
  if (callerId == null || callerId.isEmpty) {
    return const ContactVisibilityDecision.hidden(
      ContactDenyReason.unauthenticated,
    );
  }
  final isParticipant = callerId == participantA || callerId == participantB;
  if (!isParticipant) {
    return const ContactVisibilityDecision.hidden(
      ContactDenyReason.notParticipant,
    );
  }
  if (!matchActive) {
    return const ContactVisibilityDecision.hidden(
      ContactDenyReason.matchInactive,
    );
  }
  if (blocked) {
    return const ContactVisibilityDecision.hidden(ContactDenyReason.blocked);
  }
  if (!otherConsented || consentScope == null) {
    return const ContactVisibilityDecision.hidden(
      ContactDenyReason.consentRequired,
    );
  }
  final sharePhone =
      consentScope == ContactScope.phone ||
      consentScope == ContactScope.phoneAndEmail;
  final shareEmail =
      consentScope == ContactScope.email ||
      consentScope == ContactScope.phoneAndEmail;
  return ContactVisibilityDecision.granted(
    phone: sharePhone ? otherPhone : null,
    email: shareEmail ? otherEmail : null,
  );
}
