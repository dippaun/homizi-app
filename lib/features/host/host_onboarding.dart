import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/safety/domain/contact_visibility_policy.dart';

/// Roles one account can hold together. `roomie` maps to the existing
/// `flatmate` host category when a single column is required.
enum HostRole {
  owner('owner', 'Property Owner', 'Owner'),
  broker('broker', 'Broker / Agent', 'Broker'),
  roomie('roomie', 'Existing Tenant / Roomie', 'Roomie'),
  company('company', 'Company / Property Management', 'Company');

  const HostRole(this.wire, this.title, this.chip);

  final String wire;
  final String title;
  final String chip;

  static HostRole? fromWire(String raw) {
    for (final role in HostRole.values) {
      if (role.wire == raw) {
        return role;
      }
    }
    return null;
  }
}

const hostRoleDetails = <HostRole, String>{
  HostRole.owner: 'I own the property and want to rent it out.',
  HostRole.broker: 'I help property owners to find tenants.',
  HostRole.roomie:
      'I already live in a rented property and want to find a compatible person to share the room or flat.',
  HostRole.company: 'I represent a company or manage multiple properties.',
};

enum PropertyAuthKind {
  ownerDocument('owner_document', 'Owner document'),
  brokerId('broker_id', 'Broker ID'),
  tenantPermission('tenant_permission', 'Tenant permission'),
  companyRegistration('company_registration', 'Company registration');

  const PropertyAuthKind(this.wire, this.label);

  final String wire;
  final String label;

  static PropertyAuthKind? fromWire(String raw) {
    for (final kind in PropertyAuthKind.values) {
      if (kind.wire == raw) {
        return kind;
      }
    }
    return null;
  }
}

enum PropertyAuthStatus {
  notSubmitted('not_submitted', 'Not submitted'),
  underReview('under_review', 'Under review'),
  verified('verified', 'Verified');

  const PropertyAuthStatus(this.wire, this.label);

  final String wire;
  final String label;

  static PropertyAuthStatus? fromWire(String raw) {
    for (final status in PropertyAuthStatus.values) {
      if (status.wire == raw) {
        return status;
      }
    }
    return null;
  }
}

enum HostPlan {
  free('free', 'Free'),
  premium('premium', 'Premium');

  const HostPlan(this.wire, this.label);

  final String wire;
  final String label;
}

const hostResponseTimes = <String>[
  'Replies within 2 hours',
  'Replies within 24 hours',
  'Replies within 2 days',
];

const hostPreferredTenantTypes = <String>[
  'Working professional',
  'Student',
  'Actor / Actress',
  'Any',
];

final hostRegistrationPattern = RegExp(r'^[A-Za-z0-9/-]{5,21}$');

const hostOnboardingStepCount = 8;

const hostOnboardingSteps = <(String, String)>[
  (
    'Become a Host on Homizi',
    'List your property, room or shared space and find the right tenants or roomies.',
  ),
  (
    'Choose Your Category',
    'Select the option that best describes you. You can add multiple roles.',
  ),
  (
    'Complete Your Profile',
    'Provide your basic details to create your host profile.',
  ),
  (
    'Verify Your Identity',
    'Complete verification to build trust and get a Verified badge.',
  ),
  (
    'Additional Details',
    'Add more information to attract the right tenants or roomies.',
  ),
  (
    'Separate Trust Indicators',
    'Identity verification and property authorization are shown separately.',
  ),
  ('Category-Wise Profiles', 'Different roles, same trusted platform.'),
  (
    'List with Responsibility',
    'Help us keep Homizi safe and reliable for everyone.',
  ),
];

const hostResponsibilityRules = <String>[
  'List only genuine properties or rooms.',
  'Existing tenants can list shared rooms only with proper permission from the owner and as per rental agreement rules.',
  'Brokers should clearly identify their role and provide accurate property information.',
  'Provide genuine details and meet tenants in safe, public places.',
  'Any misuse or false listings may lead to account restriction or removal.',
];

class HostCategoryExample {
  const HostCategoryExample({
    required this.name,
    required this.role,
    required this.line,
  });

  final String name;
  final HostRole role;
  final String line;
}

const hostCategoryExamples = <HostCategoryExample>[
  HostCategoryExample(
    name: 'Amit Mehta',
    role: HostRole.owner,
    line: 'Owns property in Andheri, Mumbai',
  ),
  HostCategoryExample(
    name: 'Neha Sharma',
    role: HostRole.broker,
    line: 'Helps find properties across Pune',
  ),
  HostCategoryExample(
    name: 'Kunal Verma',
    role: HostRole.roomie,
    line: 'Looking for a roomie in a 2BHK',
  ),
  HostCategoryExample(
    name: 'UrbanStay Homes',
    role: HostRole.company,
    line: 'Manages rental properties in Gurgaon',
  ),
];

/// Illustrative broker. Identity and property checks are not the same thing.
const rohanTrustName = 'Rohan S.';
const rohanTrustPlace = 'Ahmedabad, Gujarat';
const rohanTrustRole = 'Broker / Agent';

const rohanPropertyExamples = <PropertyAuthKind, PropertyAuthStatus>{
  PropertyAuthKind.ownerDocument: PropertyAuthStatus.underReview,
  PropertyAuthKind.brokerId: PropertyAuthStatus.notSubmitted,
  PropertyAuthKind.companyRegistration: PropertyAuthStatus.notSubmitted,
};

class HostOnboardingDraft {
  const HostOnboardingDraft({
    this.roles = const {},
    this.agreementPermitsShare = false,
    this.fullName = '',
    this.nickname = '',
    this.gender,
    this.mobile = '',
    this.email = '',
    this.bio = '',
    this.responseTime,
    this.preferredTypes = const {},
    this.companyName = '',
    this.registrationNo = '',
    this.plan = HostPlan.free,
    this.authorizations = const {},
    this.acceptedResponsibility = false,
  });

  final Set<HostRole> roles;
  final bool agreementPermitsShare;

  /// Legal name. Internal only. Never placed on a public card.
  final String fullName;
  final String nickname;
  final String? gender;

  /// Kept for the OTP step. Public rows and cards omit both.
  final String mobile;
  final String email;
  final String bio;
  final String? responseTime;
  final Set<String> preferredTypes;
  final String companyName;
  final String registrationNo;
  final HostPlan plan;
  final Map<PropertyAuthKind, PropertyAuthStatus> authorizations;
  final bool acceptedResponsibility;

  bool get includesCompany => roles.contains(HostRole.company);

  HostOnboardingDraft copyWith({
    Set<HostRole>? roles,
    bool? agreementPermitsShare,
    String? fullName,
    String? nickname,
    String? gender,
    bool clearGender = false,
    String? mobile,
    String? email,
    String? bio,
    String? responseTime,
    bool clearResponseTime = false,
    Set<String>? preferredTypes,
    String? companyName,
    String? registrationNo,
    HostPlan? plan,
    Map<PropertyAuthKind, PropertyAuthStatus>? authorizations,
    bool? acceptedResponsibility,
  }) {
    return HostOnboardingDraft(
      roles: roles ?? this.roles,
      agreementPermitsShare:
          agreementPermitsShare ?? this.agreementPermitsShare,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      gender: clearGender ? null : (gender ?? this.gender),
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      responseTime: clearResponseTime
          ? null
          : (responseTime ?? this.responseTime),
      preferredTypes: preferredTypes ?? this.preferredTypes,
      companyName: companyName ?? this.companyName,
      registrationNo: registrationNo ?? this.registrationNo,
      plan: plan ?? this.plan,
      authorizations: authorizations ?? this.authorizations,
      acceptedResponsibility:
          acceptedResponsibility ?? this.acceptedResponsibility,
    );
  }
}

/// Property documents that belong to the roles this person selected.
List<PropertyAuthKind> authorizationKindsFor(Set<HostRole> roles) {
  return [
    if (roles.contains(HostRole.owner)) PropertyAuthKind.ownerDocument,
    if (roles.contains(HostRole.broker)) PropertyAuthKind.brokerId,
    if (roles.contains(HostRole.roomie)) PropertyAuthKind.tenantPermission,
    if (roles.contains(HostRole.company)) PropertyAuthKind.companyRegistration,
  ];
}

PropertyAuthStatus authorizationStatus(
  HostOnboardingDraft draft,
  PropertyAuthKind kind,
) {
  return draft.authorizations[kind] ?? PropertyAuthStatus.notSubmitted;
}

/// A person can ask for review. They cannot mark their own document verified.
HostOnboardingDraft submitAuthorization(
  HostOnboardingDraft draft,
  PropertyAuthKind kind,
) {
  final current = authorizationStatus(draft, kind);
  if (current == PropertyAuthStatus.verified) {
    return draft;
  }
  final next = Map<PropertyAuthKind, PropertyAuthStatus>.from(
    draft.authorizations,
  );
  next[kind] = PropertyAuthStatus.underReview;
  return draft.copyWith(authorizations: next);
}

/// Existing `host_profiles.host_category` holds one value. Owner wins, then
/// broker, company, and the roomie role stored as flatmate.
String primaryHostCategory(Set<HostRole> roles) {
  if (roles.contains(HostRole.owner)) {
    return 'owner';
  }
  if (roles.contains(HostRole.broker)) {
    return 'broker';
  }
  if (roles.contains(HostRole.company)) {
    return 'company';
  }
  if (roles.contains(HostRole.roomie)) {
    return 'flatmate';
  }
  return 'other';
}

({String first, String last}) splitLegalName(String full) {
  final parts = full
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return (first: '', last: '');
  }
  if (parts.length == 1) {
    return (first: parts.first, last: parts.first);
  }
  return (first: parts.first, last: parts.sublist(1).join(' '));
}

String? validateHostFullName(String raw) {
  final name = raw.trim();
  if (name.length < 2 || name.length > 80) {
    return 'Enter your full name.';
  }
  if (!RegExp(r"^[\p{L}][\p{L} .'-]*$", unicode: true).hasMatch(name)) {
    return 'Use letters in this name.';
  }
  return null;
}

List<String> hostOnboardingErrors({
  required HostOnboardingDraft draft,
  required int step,
  required bool identityComplete,
}) {
  final issues = <String>[];
  if (step == 1) {
    if (draft.roles.isEmpty) {
      issues.add('Choose a category.');
    }
    if (draft.roles.contains(HostRole.roomie) && !draft.agreementPermitsShare) {
      issues.add('Confirm that your rental agreement permits sharing.');
    }
  } else if (step == 2) {
    final name = validateHostFullName(draft.fullName);
    if (name != null) {
      issues.add(name);
    }
    final nickname = validatePersonName(
      draft.nickname,
      'Enter a public nickname.',
    );
    if (nickname != null) {
      issues.add(nickname);
    }
    final gender = draft.gender;
    if (gender != null && !profileGenderOptions.contains(gender)) {
      issues.add('Choose a gender.');
    }
    final mobile = validateIndianMobile(draft.mobile);
    if (mobile != null) {
      issues.add(mobile);
    }
    final email = validateEmailAddress(draft.email);
    if (email != null) {
      issues.add(email);
    }
  } else if (step == 3) {
    if (!identityComplete) {
      issues.add('Finish mobile, email, Aadhaar, and selfie verification.');
    }
  } else if (step == 4) {
    if (draft.bio.trim().length > 280) {
      issues.add('Keep the bio to 280 characters.');
    }
    final response = draft.responseTime;
    if (response != null && !hostResponseTimes.contains(response)) {
      issues.add('Choose a response time.');
    }
    if (draft.preferredTypes.any(
      (type) => !hostPreferredTenantTypes.contains(type),
    )) {
      issues.add('Choose a preferred tenant type.');
    }
    if (draft.includesCompany) {
      final company = draft.companyName.trim();
      if (company.isEmpty) {
        issues.add('Enter the company name.');
      } else if (company.length > 120) {
        issues.add('Company name must be 120 characters or fewer.');
      }
      final registration = draft.registrationNo.trim();
      if (registration.isEmpty) {
        issues.add('Enter the company registration number.');
      } else if (!hostRegistrationPattern.hasMatch(registration)) {
        issues.add('Enter a valid registration number.');
      }
    }
  } else if (step == 7 && !draft.acceptedResponsibility) {
    issues.add('Accept the listing rules to finish.');
  }
  return issues;
}

const hostPublicColumns = <String>{
  'public_nickname',
  'roles',
  'bio',
  'response_time',
  'preferred_tenant_types',
  'subscription_plan',
  'show_photo_to_verified',
  'company_name',
};

/// Safe payload. Legal name, mobile, email, registration number, and Aadhaar
/// are absent on purpose.
Map<String, Object?> hostOnboardingPublicRow(
  HostOnboardingDraft draft, {
  bool showPhotoToVerifiedUsers = false,
}) {
  final row = <String, Object?>{
    'public_nickname': draft.nickname.trim(),
    'roles': [
      for (final role in HostRole.values)
        if (draft.roles.contains(role)) role.wire,
    ],
    'bio': draft.bio.trim(),
    'response_time': draft.responseTime,
    'preferred_tenant_types': draft.preferredTypes.toList(),
    'subscription_plan': draft.plan.wire,
    'show_photo_to_verified': showPhotoToVerifiedUsers,
  };
  if (draft.includesCompany && draft.companyName.trim().isNotEmpty) {
    row['company_name'] = draft.companyName.trim();
  }
  return row;
}

bool hostPublicRowHidesPrivateColumns(Map<String, Object?> row) {
  const banned = {
    'full_name',
    'legal_full_name',
    'first_name',
    'last_name',
    'mobile',
    'email',
    'phone',
    'aadhaar',
    'registration_no',
  };
  return row.keys.every(hostPublicColumns.contains) &&
      banned.every((column) => !row.containsKey(column));
}

class HostPrivacyView {
  const HostPrivacyView({
    required this.publicName,
    required this.showsPhoto,
    required this.phone,
    required this.email,
    required this.identityBadges,
  });

  final String publicName;
  final bool showsPhoto;
  final String? phone;
  final String? email;
  final List<String> identityBadges;
}

HostPrivacyView hostPrivacyView({
  required String nickname,
  required ProfileCreateDraft profile,
  required ContactVisibilityDecision contact,
}) {
  final pub = publicProfileFromDraft(profile).copyWith(nickname: nickname);
  return HostPrivacyView(
    publicName: pub.publicName,
    showsPhoto: pub.showsPhoto,
    phone: contact.visible ? contact.phone : null,
    email: contact.visible ? contact.email : null,
    identityBadges: pub.badges,
  );
}

/// Onboarding has no match yet, so contact stays hidden even if a number was
/// typed for OTP.
HostPrivacyView hostOnboardingPrivacy({
  required HostOnboardingDraft host,
  required ProfileCreateDraft profile,
}) {
  final decision = evaluateContactVisibility(
    callerId: 'viewer',
    participantA: 'viewer',
    participantB: 'host',
    matchActive: false,
    blocked: false,
    otherConsented: true,
    consentScope: ContactScope.phoneAndEmail,
    otherPhone: host.mobile,
    otherEmail: host.email,
  );
  return hostPrivacyView(
    nickname: host.nickname,
    profile: profile,
    contact: decision,
  );
}
