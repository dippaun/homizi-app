/// Trust signals from the server. Phone and email flags mean a contact is
/// on file. Aadhaar and face flags are true only when verification says so.
/// None of these fields carries a phone number, an email, or an Aadhaar number.
class UserBadges {
  const UserBadges({
    this.phoneVerified = false,
    this.emailVerified = false,
    this.profileComplete = false,
    this.idVerifiedDemo = false,
    this.aadhaarVerified = false,
    this.faceVerified = false,
  });

  final bool phoneVerified;
  final bool emailVerified;
  final bool profileComplete;

  /// Legacy profile flag. It is not shown and it is not an identity result.
  final bool idVerifiedDemo;

  final bool aadhaarVerified;
  final bool faceVerified;

  bool get anyIdentity => aadhaarVerified || faceVerified;

  bool get any =>
      phoneVerified ||
      emailVerified ||
      profileComplete ||
      idVerifiedDemo ||
      anyIdentity;

  UserBadges copyWith({
    bool? phoneVerified,
    bool? emailVerified,
    bool? profileComplete,
    bool? idVerifiedDemo,
    bool? aadhaarVerified,
    bool? faceVerified,
  }) {
    return UserBadges(
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      profileComplete: profileComplete ?? this.profileComplete,
      idVerifiedDemo: idVerifiedDemo ?? this.idVerifiedDemo,
      aadhaarVerified: aadhaarVerified ?? this.aadhaarVerified,
      faceVerified: faceVerified ?? this.faceVerified,
    );
  }

  factory UserBadges.fromRow(Map<String, dynamic> row) {
    return UserBadges(
      phoneVerified: _flag(row['phone_verified']),
      emailVerified: _flag(row['email_verified']),
      profileComplete: _flag(row['profile_complete']),
      idVerifiedDemo: _flag(row['id_verified_demo']),
      aadhaarVerified: _flag(row['aadhaar_verified']),
      faceVerified: _flag(row['face_verified']),
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
