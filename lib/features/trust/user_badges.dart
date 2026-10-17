/// Mock trust signals derived on the server. None of these fields is a
/// government identity check, and none of them carries a phone or an email.
class UserBadges {
  const UserBadges({
    this.phoneVerified = false,
    this.emailVerified = false,
    this.profileComplete = false,
    this.idVerifiedDemo = false,
  });

  final bool phoneVerified;
  final bool emailVerified;
  final bool profileComplete;

  /// Demo toggle only. No document, photo, or government ID is stored.
  final bool idVerifiedDemo;

  bool get any =>
      phoneVerified || emailVerified || profileComplete || idVerifiedDemo;

  UserBadges copyWith({
    bool? phoneVerified,
    bool? emailVerified,
    bool? profileComplete,
    bool? idVerifiedDemo,
  }) {
    return UserBadges(
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      profileComplete: profileComplete ?? this.profileComplete,
      idVerifiedDemo: idVerifiedDemo ?? this.idVerifiedDemo,
    );
  }

  factory UserBadges.fromRow(Map<String, dynamic> row) {
    return UserBadges(
      phoneVerified: _flag(row['phone_verified']),
      emailVerified: _flag(row['email_verified']),
      profileComplete: _flag(row['profile_complete']),
      idVerifiedDemo: _flag(row['id_verified_demo']),
    );
  }
}

bool _flag(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value == 'true' || value == 't';
  }
  return false;
}
