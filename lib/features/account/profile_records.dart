import 'package:homizi/core/verification/identity_verification_gateway.dart';

class TenantProfile {
  const TenantProfile({
    this.displayName = '',
    this.occupation = '',
    this.bio = '',
    this.verification = VerificationStatus.notStarted,
  });

  final String displayName;
  final String occupation;
  final String bio;
  final VerificationStatus verification;

  TenantProfile copyWith({
    String? displayName,
    String? occupation,
    String? bio,
    VerificationStatus? verification,
  }) {
    return TenantProfile(
      displayName: displayName ?? this.displayName,
      occupation: occupation ?? this.occupation,
      bio: bio ?? this.bio,
      verification: verification ?? this.verification,
    );
  }
}

class HostProfile {
  const HostProfile({this.category = 'owner', this.companyName = ''});

  final String category;
  final String companyName;

  HostProfile copyWith({String? category, String? companyName}) {
    return HostProfile(
      category: category ?? this.category,
      companyName: companyName ?? this.companyName,
    );
  }
}

const forbiddenProfileColumns = {
  'phone',
  'email',
  'date_of_birth',
  'verification_status',
  'aadhaar',
};

/// Columns the client may write on `profiles`. Verification is a server function.
Map<String, Object?> tenantProfileColumns(TenantProfile profile) {
  final occupation = profile.occupation.trim();
  final bio = profile.bio.trim();
  return {
    'display_name': profile.displayName.trim(),
    'occupation': occupation.isEmpty ? null : occupation,
    'public_bio': bio.isEmpty ? null : bio,
  };
}

Map<String, Object?> hostProfileColumns(HostProfile profile) {
  final company = profile.companyName.trim();
  return {
    'host_category': profile.category,
    'company_name': company.isEmpty ? null : company,
  };
}
