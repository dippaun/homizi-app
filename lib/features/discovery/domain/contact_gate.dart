/// What the contact panel is allowed to show.
///
/// Built only from `get_contact_visibility`. A hidden result drops any phone
/// or email that arrived beside `visible: false`.
class ContactGate {
  const ContactGate.hidden(this.reason)
    : visible = false,
      phone = null,
      email = null;

  const ContactGate.granted({this.phone, this.email})
    : visible = true,
      reason = 'granted';

  final bool visible;
  final String reason;
  final String? phone;
  final String? email;

  bool get showsContact => phone != null || email != null;

  String get hiddenCopy {
    switch (reason) {
      case 'blocked':
        return 'Contact stays hidden because one of you blocked the other.';
      case 'not_found':
        return 'Contact stays hidden. This match is not available to you.';
      case 'match_inactive':
        return 'Contact stays hidden. The match is not active.';
      case 'unauthenticated':
        return 'Contact stays hidden until you sign in.';
      case 'consent_required':
      default:
        return 'Contact stays hidden until you both match and they consent. This screen does not hold a phone number or an email address.';
    }
  }

  static ContactGate parse(Object? raw) {
    if (raw is! Map) {
      return const ContactGate.hidden('not_found');
    }
    final reason = raw['reason'] is String
        ? raw['reason'] as String
        : 'consent_required';
    if (raw['visible'] != true) {
      return ContactGate.hidden(reason);
    }
    final phone = _clean(raw['phone']);
    final email = _clean(raw['email']);
    if (phone == null && email == null) {
      return const ContactGate.hidden('consent_required');
    }
    return ContactGate.granted(phone: phone, email: email);
  }
}

String? _clean(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
