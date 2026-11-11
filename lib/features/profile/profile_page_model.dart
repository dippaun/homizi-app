import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/domain/profile_completion.dart';
import 'package:homizi/features/profile/domain/profile_contact.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';

/// The four profile layouts in the profile spec.
enum ProfilePageRole { tenant, owner, broker, roomie }

/// `owner` is the spec name. `host` is the account wire for the same layout.
ProfilePageRole? profilePageRoleFromQuery(String? raw) {
  return switch (raw) {
    'tenant' => ProfilePageRole.tenant,
    'owner' || 'host' => ProfilePageRole.owner,
    'broker' => ProfilePageRole.broker,
    'roomie' || 'roommate' => ProfilePageRole.roomie,
    _ => null,
  };
}

enum ProfilePillTone { good, pending, neutral }

enum ProfileActionKind { push, go, share, preview }

class ProfileStat {
  const ProfileStat({
    required this.value,
    required this.label,
    required this.route,
    this.go = false,
    this.valueKey,
  });

  final String value;
  final String label;
  final String route;
  final bool go;
  final Key? valueKey;
}

class ProfilePriority {
  const ProfilePriority({required this.title, required this.detail});

  final String title;
  final String detail;
}

class ProfileChip {
  const ProfileChip({
    required this.label,
    required this.route,
    this.go = false,
  });

  final String label;
  final String route;
  final bool go;
}

class ProfileListing {
  const ProfileListing({
    required this.title,
    required this.place,
    required this.price,
    required this.meta,
    required this.route,
    this.status,
    this.tone = ProfilePillTone.neutral,
    this.matchLabel,
    this.go = false,
  });

  final String title;
  final String place;
  final String price;
  final String meta;
  final String route;
  final String? status;
  final ProfilePillTone tone;
  final String? matchLabel;
  final bool go;
}

class ProfileFact {
  const ProfileFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class ProfileCheck {
  const ProfileCheck({
    required this.icon,
    required this.title,
    required this.detail,
    required this.status,
    required this.tone,
    required this.route,
    this.detailKey,
    this.statusKey,
  });

  final IconData icon;
  final String title;
  final String detail;
  final String status;
  final ProfilePillTone tone;
  final String route;
  final Key? detailKey;
  final Key? statusKey;

  bool get passed => tone == ProfilePillTone.good && status == 'Verified';
}

class ProfilePerson {
  const ProfilePerson({
    required this.initials,
    required this.name,
    required this.detail,
    this.open = false,
  });

  final String initials;
  final String name;
  final String detail;
  final bool open;
}

class ProfileBlock {
  const ProfileBlock({
    required this.title,
    this.actionLabel,
    this.actionRoute,
    this.actionGo = false,
    this.actionKey,
    this.priorities = const [],
    this.chips = const [],
    this.listings = const [],
    this.facts = const [],
    this.checks = const [],
    this.people = const [],
    this.footnote,
  });

  final String title;
  final String? actionLabel;
  final String? actionRoute;
  final bool actionGo;
  final Key? actionKey;
  final List<ProfilePriority> priorities;
  final List<ProfileChip> chips;
  final List<ProfileListing> listings;
  final List<ProfileFact> facts;
  final List<ProfileCheck> checks;
  final List<ProfilePerson> people;
  final String? footnote;
}

class ProfileAction {
  const ProfileAction({
    required this.label,
    required this.icon,
    required this.kind,
    this.route = '',
    this.buttonKey,
  });

  final String label;
  final IconData icon;
  final ProfileActionKind kind;
  final String route;
  final Key? buttonKey;
}

class ProfilePageModel {
  const ProfilePageModel({
    required this.role,
    required this.initials,
    required this.name,
    required this.handleLine,
    required this.roleChip,
    required this.roleIcon,
    required this.verified,
    required this.splitPlace,
    required this.placeLeft,
    required this.placeRight,
    required this.bio,
    required this.stats,
    required this.blocks,
    required this.primary,
    required this.secondary,
    required this.illustration,
  });

  final ProfilePageRole role;
  final String initials;
  final String name;
  final String handleLine;
  final String roleChip;
  final IconData roleIcon;

  /// Header tick and Verified pill. True for the spec samples, and for a
  /// signed-in person only after Digio has passed both Aadhaar and the selfie.
  final bool verified;
  final bool splitPlace;
  final String placeLeft;
  final String placeRight;
  final String bio;
  final List<ProfileStat> stats;
  final List<ProfileBlock> blocks;
  final ProfileAction primary;
  final ProfileAction secondary;

  /// Spec sample used for screenshots. It is not a Digio result.
  final bool illustration;

  bool get darkHeader =>
      role == ProfilePageRole.owner || role == ProfilePageRole.broker;
}

class ProfilePageInput {
  const ProfilePageInput({
    required this.role,
    required this.illustration,
    required this.profile,
    required this.host,
    required this.activity,
    required this.badges,
    required this.kyc,
    required this.own,
    required this.contact,
    required this.listings,
  });

  final ProfilePageRole role;
  final bool illustration;
  final TenantProfile profile;
  final HostProfile host;
  final ProfileActivity activity;
  final UserBadges badges;
  final KycSnapshot kyc;
  final PublicProfile own;
  final ShownContact contact;
  final List<OwnerListing> listings;
}

ProfilePageModel resolveProfilePage(ProfilePageInput input) {
  if (input.illustration) {
    return profileSample(input.role);
  }
  final named = input.profile.displayName.trim().isNotEmpty;
  if (!named) {
    return _withRealIdentityChecks(profileSample(input.role), input);
  }
  return _namedPage(input);
}

ProfilePageModel profileSample(ProfilePageRole role) {
  return switch (role) {
    ProfilePageRole.tenant => _tenantSample(),
    ProfilePageRole.owner => _ownerSample(),
    ProfilePageRole.broker => _brokerSample(),
    ProfilePageRole.roomie => _roomieSample(),
  };
}

const _addListing = ProfileAction(
  label: 'Add a listing',
  icon: Icons.add,
  kind: ProfileActionKind.push,
  route: '${RoutePaths.listingEditor}?fresh=1',
  buttonKey: Key('profile-primary-action'),
);

const _editProfileTenant = ProfileAction(
  label: 'Edit profile',
  icon: Icons.edit_outlined,
  kind: ProfileActionKind.push,
  route: RoutePaths.tenantProfile,
  buttonKey: Key('profile-primary-action'),
);

const _editProfileHost = ProfileAction(
  label: 'Edit profile',
  icon: Icons.edit_outlined,
  kind: ProfileActionKind.push,
  route: RoutePaths.hostProfile,
  buttonKey: Key('profile-secondary-action'),
);

const _previewHosts = ProfileAction(
  label: 'Preview as hosts see it',
  icon: Icons.visibility_outlined,
  kind: ProfileActionKind.preview,
  buttonKey: Key('profile-preview-hosts'),
);

const _shareRoom = ProfileAction(
  label: 'Share my room',
  icon: Icons.ios_share,
  kind: ProfileActionKind.share,
  buttonKey: Key('profile-primary-action'),
);

ProfilePageModel _tenantSample() {
  return ProfilePageModel(
    role: ProfilePageRole.tenant,
    initials: 'PN',
    name: 'Priya Nair',
    handleLine: '@priya.n · she/her',
    roleChip: 'Tenant · Working professional',
    roleIcon: Icons.person_outline,
    verified: true,
    splitPlace: false,
    placeLeft: 'Mumbai',
    placeRight: 'Member since Oct 2026',
    bio:
        'Software engineer at a fintech in Powai. Quiet, tidy, early riser. Looking for a private room close to work.',
    stats: const [
      ProfileStat(
        value: '12',
        label: 'Saved',
        route: RoutePaths.saved,
        go: true,
        valueKey: Key('activity-saved'),
      ),
      ProfileStat(value: '8', label: 'Liked', route: RoutePaths.recentlyViewed),
      ProfileStat(
        value: '3',
        label: 'Matches',
        route: RoutePaths.matches,
        go: true,
        valueKey: Key('activity-matches'),
      ),
    ],
    blocks: [
      const ProfileBlock(
        title: 'My top priorities',
        actionLabel: 'Edit',
        actionRoute: RoutePaths.matchPriorities,
        priorities: [
          ProfilePriority(
            title: 'Commute to office',
            detail: 'Powai · max 30 min by car',
          ),
          ProfilePriority(title: 'Budget', detail: '₹18,000 – ₹25,000 / month'),
          ProfilePriority(
            title: 'Location',
            detail: 'Bandra West, Khar, Andheri',
          ),
          ProfilePriority(title: 'Move-in date', detail: '1 Dec 2026'),
          ProfilePriority(
            title: 'Furnishing',
            detail: 'Semi-furnished or furnished',
          ),
        ],
      ),
      ProfileBlock(
        title: 'Lifestyle',
        chips: [
          for (final label in const [
            'Non-smoker',
            'Non-drinker',
            'Vegetarian',
            'Early riser',
            'No pets',
            'Works from office',
          ])
            ProfileChip(label: label, route: RoutePaths.requirement),
        ],
      ),
      const ProfileBlock(
        title: 'Latest matches',
        actionLabel: 'See all',
        actionRoute: RoutePaths.matches,
        actionGo: true,
        actionKey: Key('profile-see-all'),
        listings: [
          ProfileListing(
            title: 'Private Room in 2BHK',
            place: 'Bandra West, Mumbai',
            price: '₹25,000 / month',
            meta: 'Host: Rohan S. · 28 min commute',
            matchLabel: '92% Match',
            route: RoutePaths.matches,
            go: true,
          ),
          ProfileListing(
            title: '1BHK Apartment',
            place: 'Andheri East, Mumbai',
            price: '₹28,000 / month',
            meta: 'Host: Amit M. · 32 min commute',
            matchLabel: '78% Match',
            route: RoutePaths.matches,
            go: true,
          ),
        ],
      ),
      ProfileBlock(title: 'Verification', checks: _sampleIdentityChecks()),
    ],
    primary: _editProfileTenant,
    secondary: _previewHosts,
    illustration: true,
  );
}

ProfilePageModel _ownerSample() {
  return ProfilePageModel(
    role: ProfilePageRole.owner,
    initials: 'RS',
    name: 'Rohan Sharma',
    handleLine: '@rohan.s · Owner',
    roleChip: 'Property owner',
    roleIcon: Icons.home_outlined,
    verified: true,
    splitPlace: true,
    placeLeft: 'Andheri West, Mumbai',
    placeRight: 'Member since Sep 2026',
    bio:
        'I own two flats in western Mumbai. I prefer working professionals who plan to stay at least 11 months.',
    stats: const [
      ProfileStat(
        value: '2',
        label: 'Listings',
        route: RoutePaths.ownerDashboard,
        valueKey: Key('activity-saved'),
      ),
      ProfileStat(
        value: '26',
        label: 'Interested',
        route: RoutePaths.hostLeads,
      ),
      ProfileStat(
        value: '5',
        label: 'Matches',
        route: RoutePaths.matches,
        go: true,
        valueKey: Key('activity-matches'),
      ),
    ],
    blocks: [
      const ProfileBlock(
        title: 'My listings',
        actionLabel: 'Manage',
        actionRoute: RoutePaths.ownerDashboard,
        listings: [
          ProfileListing(
            title: 'Private Room in 2BHK',
            place: 'Bandra West, Mumbai',
            price: '₹25,000 / month',
            meta: '18 interested · posted 6 Nov',
            status: 'Live',
            tone: ProfilePillTone.good,
            route: '${RoutePaths.listingEditor}?fresh=1',
          ),
          ProfileListing(
            title: '1BHK Apartment',
            place: 'Andheri East, Mumbai',
            price: '₹28,000 / month',
            meta: 'Add 2 more photos to publish',
            status: 'Draft',
            route: '${RoutePaths.listingEditor}?fresh=1',
          ),
        ],
      ),
      const ProfileBlock(
        title: 'Tenant preferences',
        actionLabel: 'Edit',
        actionRoute: RoutePaths.hostProfile,
        priorities: [
          ProfilePriority(
            title: 'Working professional',
            detail: 'Students also considered',
          ),
          ProfilePriority(title: 'Non-smoker', detail: 'Inside the flat'),
          ProfilePriority(title: 'Non-drinker', detail: 'No parties'),
          ProfilePriority(title: 'Long-term stay', detail: '11 months or more'),
          ProfilePriority(title: 'Any gender', detail: 'Single occupancy'),
        ],
      ),
      const ProfileBlock(
        title: 'Response',
        facts: [
          ProfileFact(
            icon: Icons.schedule,
            label: 'Usually responds',
            value: 'Within 2 hours',
          ),
          ProfileFact(
            icon: Icons.chat_bubble_outline,
            label: 'Contact shared',
            value: 'After a match',
          ),
          ProfileFact(
            icon: Icons.event_outlined,
            label: 'Visits',
            value: 'Weekends, 10 AM – 6 PM',
          ),
        ],
      ),
      ProfileBlock(
        title: 'Identity verification',
        checks: _sampleIdentityChecks(),
      ),
      const ProfileBlock(
        title: 'Property authorisation',
        checks: [
          ProfileCheck(
            icon: Icons.description_outlined,
            title: 'Owner document',
            detail: 'Sale deed · Bandra West flat',
            status: 'Under review',
            tone: ProfilePillTone.pending,
            route: RoutePaths.verifyIdentity,
          ),
          ProfileCheck(
            icon: Icons.bolt_outlined,
            title: 'Electricity bill',
            detail: 'Matches listing address',
            status: 'Verified',
            tone: ProfilePillTone.good,
            route: RoutePaths.verifyIdentity,
          ),
        ],
        footnote:
            'A verified person is not automatically the owner. Property proof is checked separately.',
      ),
    ],
    primary: _addListing,
    secondary: _editProfileHost,
    illustration: true,
  );
}

ProfilePageModel _brokerSample() {
  return ProfilePageModel(
    role: ProfilePageRole.broker,
    initials: 'NK',
    name: 'Neha Kulkarni',
    handleLine: '@nehak.homes · Broker',
    roleChip: 'Broker / Agent',
    roleIcon: Icons.badge_outlined,
    verified: true,
    splitPlace: false,
    placeLeft: 'Pune',
    placeRight: 'Member since Aug 2026',
    bio:
        'I help owners in west and east Pune find verified tenants. Brokerage is always shown upfront on the listing.',
    stats: const [
      ProfileStat(
        value: '14',
        label: 'Active listings',
        route: RoutePaths.brokerListings,
        valueKey: Key('activity-saved'),
      ),
      ProfileStat(value: '9', label: 'Owners', route: RoutePaths.brokerSeekers),
      ProfileStat(
        value: '21',
        label: 'Deals (12 mo)',
        route: RoutePaths.brokerLeads,
        valueKey: Key('activity-matches'),
      ),
    ],
    blocks: [
      ProfileBlock(
        title: 'Areas I cover',
        chips: [
          for (final label in const [
            'Baner',
            'Hinjewadi',
            'Wakad',
            'Kharadi',
            'Viman Nagar',
            'Aundh',
          ])
            ProfileChip(label: label, route: RoutePaths.explore, go: true),
        ],
      ),
      const ProfileBlock(
        title: 'Brokerage & business',
        facts: [
          ProfileFact(
            icon: Icons.payments_outlined,
            label: 'Brokerage',
            value: '1 month rent',
          ),
          ProfileFact(
            icon: Icons.apartment_outlined,
            label: 'Firm',
            value: 'Kulkarni Realty',
          ),
          ProfileFact(
            icon: Icons.schedule,
            label: 'Usually responds',
            value: 'Within 1 hour',
          ),
          ProfileFact(
            icon: Icons.event_outlined,
            label: 'Visits',
            value: 'All days, 9 AM – 8 PM',
          ),
        ],
      ),
      const ProfileBlock(
        title: 'Featured listings',
        actionLabel: 'All 14',
        actionRoute: RoutePaths.brokerListings,
        listings: [
          ProfileListing(
            title: '2BHK Apartment',
            place: 'Baner, Pune',
            price: '₹32,000 / month',
            meta: 'Owner: Suresh P. · 11 interested',
            status: 'Live',
            tone: ProfilePillTone.good,
            route: RoutePaths.brokerListings,
          ),
          ProfileListing(
            title: 'Private Room in 3BHK',
            place: 'Hinjewadi Phase 1, Pune',
            price: '₹13,500 / month',
            meta: 'Owner: Meera J. · 7 interested',
            status: 'Live',
            tone: ProfilePillTone.good,
            route: RoutePaths.brokerListings,
          ),
        ],
      ),
      ProfileBlock(
        title: 'Identity verification',
        checks: _sampleIdentityChecks(),
      ),
      const ProfileBlock(
        title: 'Broker authorisation',
        checks: [
          ProfileCheck(
            icon: Icons.badge_outlined,
            title: 'Broker ID',
            detail: 'Optional · submitted 2 Nov',
            status: 'Under review',
            tone: ProfilePillTone.pending,
            route: RoutePaths.brokerRegister,
          ),
          ProfileCheck(
            icon: Icons.verified_outlined,
            title: 'Owner mandates',
            detail: '9 of 14 listings uploaded',
            status: 'Verified',
            tone: ProfilePillTone.good,
            route: RoutePaths.brokerListings,
          ),
        ],
      ),
    ],
    primary: _addListing,
    secondary: _editProfileHost,
    illustration: true,
  );
}

ProfilePageModel _roomieSample() {
  return ProfilePageModel(
    role: ProfilePageRole.roomie,
    initials: 'KV',
    name: 'Kunal Verma',
    handleLine: '@kunal.v · he/him',
    roleChip: 'Existing tenant · Roomie',
    roleIcon: Icons.groups_outlined,
    verified: true,
    splitPlace: true,
    placeLeft: 'Koramangala, Bengaluru',
    placeRight: 'Member since Oct 2026',
    bio:
        "Product designer. I live in a 2BHK and my flatmate is moving out, so I'm looking for one more person to share it.",
    stats: const [
      ProfileStat(
        value: '1',
        label: 'Room open',
        route: RoutePaths.flatmateRooms,
        valueKey: Key('activity-saved'),
      ),
      ProfileStat(
        value: '15',
        label: 'Interested',
        route: RoutePaths.flatmateMutual,
      ),
      ProfileStat(
        value: '4',
        label: 'Matches',
        route: RoutePaths.matches,
        go: true,
        valueKey: Key('activity-matches'),
      ),
    ],
    blocks: [
      ProfileBlock(
        title: 'Room on offer',
        actionLabel: 'Edit',
        actionRoute: '${RoutePaths.listingEditor}?fresh=1',
        listings: const [
          ProfileListing(
            title: 'Private Room in 2BHK',
            place: 'Koramangala 5th Block, Bengaluru',
            price: '₹14,500 / month',
            meta: 'Available 1 Dec 2026 · attached bath',
            status: 'Live',
            tone: ProfilePillTone.good,
            route: RoutePaths.flatmateRooms,
          ),
        ],
        chips: [
          for (final label in const [
            'Furnished',
            'WiFi',
            'Washing machine',
            'Cook available',
            'Bike parking',
          ])
            ProfileChip(label: label, route: RoutePaths.flatmateRooms),
        ],
      ),
      const ProfileBlock(
        title: 'Who lives here',
        people: [
          ProfilePerson(
            initials: 'KV',
            name: 'Kunal (me)',
            detail: 'Product designer · hybrid work',
          ),
          ProfilePerson(
            initials: '+1',
            name: 'Open spot',
            detail: 'The person you match with',
            open: true,
          ),
        ],
      ),
      const ProfileBlock(
        title: "Flatmate I'm looking for",
        actionLabel: 'Edit',
        actionRoute: RoutePaths.roomiePreferences,
        priorities: [
          ProfilePriority(title: 'Working professional', detail: 'Any field'),
          ProfilePriority(title: 'Non-smoker', detail: 'Balcony is fine'),
          ProfilePriority(
            title: 'Any gender',
            detail: 'Comfortable with mixed flat',
          ),
          ProfilePriority(
            title: 'Clean & responsible',
            detail: 'Shared chores rota',
          ),
          ProfilePriority(
            title: 'Stays 11+ months',
            detail: 'Lock-in matches lease',
          ),
        ],
      ),
      const ProfileBlock(
        title: 'Owner permission',
        checks: [
          ProfileCheck(
            icon: Icons.draw_outlined,
            title: 'Owner consent to sublet',
            detail: 'Signed letter from landlord',
            status: 'Verified',
            tone: ProfilePillTone.good,
            route: RoutePaths.verifyIdentity,
          ),
          ProfileCheck(
            icon: Icons.description_outlined,
            title: 'Rent agreement',
            detail: 'Valid till Jun 2027',
            status: 'Verified',
            tone: ProfilePillTone.good,
            route: RoutePaths.agreements,
          ),
        ],
      ),
      ProfileBlock(title: 'Verification', checks: _sampleIdentityChecks()),
    ],
    primary: _shareRoom,
    secondary: const ProfileAction(
      label: 'Edit profile',
      icon: Icons.edit_outlined,
      kind: ProfileActionKind.push,
      route: RoutePaths.tenantProfile,
      buttonKey: Key('profile-secondary-action'),
    ),
    illustration: true,
  );
}

List<ProfileCheck> _sampleIdentityChecks() {
  return const [
    ProfileCheck(
      icon: Icons.smartphone_outlined,
      title: 'Mobile number',
      detail: 'OTP verified · +91 ••••• ••210',
      status: 'Verified',
      tone: ProfilePillTone.good,
      route: RoutePaths.verifyIdentity,
      detailKey: Key('profile-phone'),
    ),
    ProfileCheck(
      icon: Icons.mail_outline,
      title: 'Email',
      detail: 'OTP verified',
      status: 'Verified',
      tone: ProfilePillTone.good,
      route: RoutePaths.verifyIdentity,
    ),
    ProfileCheck(
      icon: Icons.fingerprint,
      title: 'Aadhaar',
      detail: 'Verified via Digio',
      status: 'Verified',
      tone: ProfilePillTone.good,
      route: RoutePaths.verifyIdentity,
      statusKey: Key('profile-aadhaar-status'),
    ),
    ProfileCheck(
      icon: Icons.photo_camera_outlined,
      title: 'Selfie',
      detail: 'Liveness check passed',
      status: 'Verified',
      tone: ProfilePillTone.good,
      route: RoutePaths.verifyIdentity,
      statusKey: Key('profile-selfie-status'),
    ),
  ];
}

ProfilePageModel _withRealIdentityChecks(
  ProfilePageModel sample,
  ProfilePageInput input,
) {
  final checks = _identityChecks(input);
  final verified = _digioVerified(input.kyc);
  return ProfilePageModel(
    role: sample.role,
    initials: sample.initials,
    name: sample.name,
    handleLine: sample.handleLine,
    roleChip: sample.roleChip,
    roleIcon: sample.roleIcon,
    verified: verified,
    splitPlace: sample.splitPlace,
    placeLeft: sample.placeLeft,
    placeRight: sample.placeRight,
    bio: sample.bio,
    stats: sample.stats,
    blocks: [
      for (final block in sample.blocks)
        _isIdentityBlock(block)
            ? ProfileBlock(title: block.title, checks: checks)
            : block,
    ],
    primary: sample.primary,
    secondary: sample.secondary,
    illustration: false,
  );
}

ProfilePageModel _namedPage(ProfilePageInput input) {
  final sample = profileSample(input.role);
  final name = input.profile.displayName.trim();
  final occupation = input.profile.occupation.trim();
  final bio = input.profile.bio.trim().isEmpty
      ? sample.bio
      : input.profile.bio.trim();
  final place = _place(input, sample);
  final listings = _listingsFor(input);
  return ProfilePageModel(
    role: input.role,
    initials: profileInitials(name),
    name: name,
    handleLine: _handleLine(name, occupation, input),
    roleChip: _roleChip(input.role, occupation),
    roleIcon: sample.roleIcon,
    verified: _digioVerified(input.kyc),
    splitPlace: sample.splitPlace,
    placeLeft: place.$1,
    placeRight: place.$2,
    bio: bio,
    stats: _stats(input, sample),
    blocks: [
      for (final block in sample.blocks) _namedBlock(block, input, listings),
    ],
    primary: sample.primary,
    secondary: sample.secondary,
    illustration: false,
  );
}

bool _digioVerified(KycSnapshot kyc) => kyc.aadhaarVerified && kyc.faceVerified;

bool _isIdentityBlock(ProfileBlock block) {
  return block.title == 'Verification' ||
      block.title == 'Identity verification';
}

(String, String) _place(ProfilePageInput input, ProfilePageModel sample) {
  final localities = input.profile.preferences.localities
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  final left = localities.isEmpty ? sample.placeLeft : localities.first;
  return (left, 'Member since 2026');
}

String _handleLine(String name, String occupation, ProfilePageInput input) {
  final nick = input.own.nickname.trim();
  final handle = nick.isEmpty
      ? _handleFromName(name)
      : '@${nick.replaceAll(' ', '').toLowerCase()}';
  if (occupation.isEmpty) {
    return handle;
  }
  return '$handle · $occupation';
}

String _handleFromName(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '@member';
  }
  final first = parts.first.toLowerCase();
  if (parts.length == 1) {
    return '@$first';
  }
  return '@$first.${parts.last[0].toLowerCase()}';
}

String _roleChip(ProfilePageRole role, String occupation) {
  return switch (role) {
    ProfilePageRole.tenant =>
      occupation.isEmpty ? 'Tenant' : 'Tenant · $occupation',
    ProfilePageRole.owner => 'Property owner',
    ProfilePageRole.broker => 'Broker / Agent',
    ProfilePageRole.roomie => 'Existing tenant · Roomie',
  };
}

List<ProfileStat> _stats(ProfilePageInput input, ProfilePageModel sample) {
  final saved = '${input.activity.savedCount}';
  final liked =
      '${input.activity.viewedAvailable ? input.activity.viewedCount : input.activity.requestCount}';
  final matches = '${input.activity.matchCount}';
  final listingCount = input.listings.length;
  final interested = input.listings.fold<int>(
    0,
    (sum, listing) => sum + listing.interests,
  );
  final live = input.listings
      .where(
        (listing) => listing.chip == 'live' || listing.status == 'published',
      )
      .length;
  return switch (input.role) {
    ProfilePageRole.tenant => [
      ProfileStat(
        value: saved,
        label: 'Saved',
        route: RoutePaths.saved,
        go: true,
        valueKey: const Key('activity-saved'),
      ),
      ProfileStat(
        value: liked,
        label: 'Liked',
        route: RoutePaths.recentlyViewed,
      ),
      ProfileStat(
        value: matches,
        label: 'Matches',
        route: RoutePaths.matches,
        go: true,
        valueKey: const Key('activity-matches'),
      ),
    ],
    ProfilePageRole.owner => [
      ProfileStat(
        value: listingCount == 0 ? sample.stats[0].value : '$listingCount',
        label: 'Listings',
        route: RoutePaths.ownerDashboard,
        valueKey: const Key('activity-saved'),
      ),
      ProfileStat(
        value: listingCount == 0 ? sample.stats[1].value : '$interested',
        label: 'Interested',
        route: RoutePaths.hostLeads,
      ),
      ProfileStat(
        value: input.activity.matchCount == 0 ? sample.stats[2].value : matches,
        label: 'Matches',
        route: RoutePaths.matches,
        go: true,
        valueKey: const Key('activity-matches'),
      ),
    ],
    ProfilePageRole.broker => [
      ProfileStat(
        value: live == 0 ? sample.stats[0].value : '$live',
        label: 'Active listings',
        route: RoutePaths.brokerListings,
        valueKey: const Key('activity-saved'),
      ),
      sample.stats[1],
      ProfileStat(
        value: input.activity.matchCount == 0 ? sample.stats[2].value : matches,
        label: 'Deals (12 mo)',
        route: RoutePaths.brokerLeads,
        valueKey: const Key('activity-matches'),
      ),
    ],
    ProfilePageRole.roomie => [
      ProfileStat(
        value: listingCount == 0 ? sample.stats[0].value : '$listingCount',
        label: 'Room open',
        route: RoutePaths.flatmateRooms,
        valueKey: const Key('activity-saved'),
      ),
      ProfileStat(
        value: interested == 0 ? sample.stats[1].value : '$interested',
        label: 'Interested',
        route: RoutePaths.flatmateMutual,
      ),
      ProfileStat(
        value: input.activity.matchCount == 0 ? sample.stats[2].value : matches,
        label: 'Matches',
        route: RoutePaths.matches,
        go: true,
        valueKey: const Key('activity-matches'),
      ),
    ],
  };
}

ProfileBlock _namedBlock(
  ProfileBlock block,
  ProfilePageInput input,
  List<ProfileListing> listings,
) {
  if (_isIdentityBlock(block)) {
    return ProfileBlock(title: block.title, checks: _identityChecks(input));
  }
  if (block.title == 'My top priorities' ||
      block.title == "Flatmate I'm looking for") {
    final priorities = _prioritiesFrom(input.profile.preferences);
    if (priorities.isEmpty) {
      return block;
    }
    return ProfileBlock(
      title: block.title,
      actionLabel: block.actionLabel,
      actionRoute: block.actionRoute,
      priorities: priorities,
    );
  }
  if (block.title == 'Lifestyle') {
    final chips = _lifestyleChips(input.profile.preferences);
    if (chips.isEmpty) {
      return block;
    }
    return ProfileBlock(title: block.title, chips: chips);
  }
  if (block.title == 'My listings' || block.title == 'Featured listings') {
    if (listings.isEmpty) {
      return block;
    }
    final label = block.title == 'Featured listings'
        ? 'All ${input.listings.length}'
        : block.actionLabel;
    return ProfileBlock(
      title: block.title,
      actionLabel: label,
      actionRoute: block.actionRoute,
      actionGo: block.actionGo,
      listings: listings.take(2).toList(),
    );
  }
  if (block.title == 'Room on offer') {
    if (listings.isEmpty) {
      return block;
    }
    return ProfileBlock(
      title: block.title,
      actionLabel: block.actionLabel,
      actionRoute: listings.first.route,
      listings: listings.take(1).toList(),
      chips: block.chips,
    );
  }
  if (block.title == 'Who lives here') {
    final name = input.profile.displayName.trim();
    final first = name.split(RegExp(r'\s+')).first;
    final occupation = input.profile.occupation.trim();
    return ProfileBlock(
      title: block.title,
      people: [
        ProfilePerson(
          initials: profileInitials(name),
          name: '$first (me)',
          detail: occupation.isEmpty ? 'Lives here' : occupation,
        ),
        const ProfilePerson(
          initials: '+1',
          name: 'Open spot',
          detail: 'The person you match with',
          open: true,
        ),
      ],
    );
  }
  if (block.title == 'Brokerage & business' &&
      input.host.companyName.trim().isNotEmpty) {
    return ProfileBlock(
      title: block.title,
      facts: [
        for (final fact in block.facts)
          fact.label == 'Firm'
              ? ProfileFact(
                  icon: fact.icon,
                  label: fact.label,
                  value: input.host.companyName.trim(),
                )
              : fact,
      ],
    );
  }
  if (block.title == 'Property authorisation' ||
      block.title == 'Broker authorisation' ||
      block.title == 'Owner permission') {
    return ProfileBlock(
      title: block.title,
      checks: [
        for (final check in block.checks)
          ProfileCheck(
            icon: check.icon,
            title: check.title,
            detail: 'Not added yet',
            status: 'Not verified',
            tone: ProfilePillTone.neutral,
            route: check.route,
          ),
      ],
      footnote: block.footnote,
    );
  }
  return block;
}

List<ProfileListing> _listingsFor(ProfilePageInput input) {
  if (input.role == ProfilePageRole.tenant || input.listings.isEmpty) {
    return const [];
  }
  return [
    for (final listing in input.listings) _listingRow(listing, input.role),
  ];
}

ProfileListing _listingRow(OwnerListing listing, ProfilePageRole role) {
  final live = listing.chip == 'live' || listing.status == 'published';
  final draft = listing.chip == 'draft' || listing.status == 'draft';
  final review = listing.chip == 'in_review' || listing.status == 'in_review';
  final status = listingStatusLabel(listing.chip);
  final tone = live
      ? ProfilePillTone.good
      : review
      ? ProfilePillTone.pending
      : ProfilePillTone.neutral;
  final route = draft || review
      ? '${RoutePaths.listingEditor}?id=${listing.id}'
      : RoutePaths.listing(listing.id);
  final meta = draft || review
      ? 'Add more photos to publish'
      : '${listing.interests} interested';
  return ProfileListing(
    title: listing.title,
    place: listing.place,
    price: '${formatInr(listing.rentInr)} / month',
    meta: meta,
    status: status,
    tone: tone,
    route: role == ProfilePageRole.broker && live
        ? RoutePaths.brokerListing(listing.id)
        : route,
  );
}

String listingStatusLabel(String chip) {
  return switch (chip) {
    'live' || 'published' => 'Live',
    'draft' => 'Draft',
    'in_review' => 'Under review',
    'paused' => 'Paused',
    'rented' => 'Rented',
    'expired' => 'Expired',
    _ => 'Draft',
  };
}

List<ProfilePriority> _prioritiesFrom(TenantPreferences preferences) {
  final items = <ProfilePriority>[];
  final min = preferences.budgetMinInr;
  final max = preferences.budgetMaxInr;
  if (min != null || max != null) {
    items.add(
      ProfilePriority(
        title: 'Budget',
        detail:
            '${formatInr(min ?? max ?? 0)} – ${formatInr(max ?? min ?? 0)} / month',
      ),
    );
  }
  if (preferences.localities.isNotEmpty) {
    items.add(
      ProfilePriority(
        title: 'Location',
        detail: preferences.localities.join(', '),
      ),
    );
  }
  if (preferences.propertyTypes.isNotEmpty) {
    items.add(
      ProfilePriority(
        title: 'Home',
        detail: preferences.propertyTypes
            .map(tenantPropertyTypeLabel)
            .join(', '),
      ),
    );
  }
  if (preferences.lifestyle.isNotEmpty) {
    items.add(
      ProfilePriority(
        title: 'Lifestyle',
        detail: preferences.lifestyle.map(tenantLifestyleLabel).join(', '),
      ),
    );
  }
  return items;
}

List<ProfileChip> _lifestyleChips(TenantPreferences preferences) {
  return [
    for (final item in preferences.lifestyle)
      ProfileChip(
        label: tenantLifestyleLabel(item),
        route: RoutePaths.requirement,
      ),
  ];
}

List<ProfileCheck> _identityChecks(ProfilePageInput input) {
  final phone = _masked(input.contact.phone);
  final hasPhone = phone != profileContactMissing;
  final phoneOk =
      hasPhone && (input.badges.phoneVerified || input.own.mobileVerified);
  final email = input.contact.email;
  final hasEmail = email != profileContactMissing;
  final emailOk =
      hasEmail && (input.badges.emailVerified || input.own.emailVerified);
  final aadhaar = input.kyc.aadhaarStatus;
  final face = input.kyc.faceStatus;
  return [
    ProfileCheck(
      icon: Icons.smartphone_outlined,
      title: 'Mobile number',
      detail: !hasPhone
          ? 'Not added'
          : phoneOk
          ? 'OTP verified · $phone'
          : phone,
      status: phoneOk ? 'Verified' : 'Not verified',
      tone: phoneOk ? ProfilePillTone.good : ProfilePillTone.neutral,
      route: RoutePaths.verifyIdentity,
      detailKey: const Key('profile-phone'),
    ),
    ProfileCheck(
      icon: Icons.mail_outline,
      title: 'Email',
      detail: emailOk
          ? 'OTP verified'
          : hasEmail
          ? email
          : 'Not added',
      status: emailOk ? 'Verified' : 'Not verified',
      tone: emailOk ? ProfilePillTone.good : ProfilePillTone.neutral,
      route: RoutePaths.verifyIdentity,
    ),
    ProfileCheck(
      icon: Icons.fingerprint,
      title: 'Aadhaar',
      detail: _aadhaarDetail(aadhaar),
      status: _checkStatus(aadhaar),
      tone: _checkTone(aadhaar),
      route: RoutePaths.verifyIdentity,
      statusKey: const Key('profile-aadhaar-status'),
    ),
    ProfileCheck(
      icon: Icons.photo_camera_outlined,
      title: 'Selfie',
      detail: face == KycCheckState.verified
          ? 'Liveness check passed'
          : 'Not verified yet',
      status: _checkStatus(face),
      tone: _checkTone(face),
      route: RoutePaths.verifyIdentity,
      statusKey: const Key('profile-selfie-status'),
    ),
  ];
}

String _masked(String phone) {
  if (phone == profileContactMissing || phone.trim().isEmpty) {
    return profileContactMissing;
  }
  if (containsFullIndianMobile(phone)) {
    return maskIndianMobile(phone);
  }
  return phone;
}

String _aadhaarDetail(KycCheckState state) {
  return switch (state) {
    KycCheckState.verified => 'Verified via Digio',
    KycCheckState.inProgress => 'Check in progress',
    KycCheckState.failed => 'Could not be verified',
    KycCheckState.notStarted => 'Not verified yet',
  };
}

String _checkStatus(KycCheckState state) {
  return switch (state) {
    KycCheckState.verified => 'Verified',
    KycCheckState.inProgress => 'In progress',
    KycCheckState.failed => 'Failed',
    KycCheckState.notStarted => 'Not verified',
  };
}

ProfilePillTone _checkTone(KycCheckState state) {
  return switch (state) {
    KycCheckState.verified => ProfilePillTone.good,
    KycCheckState.inProgress => ProfilePillTone.pending,
    KycCheckState.failed || KycCheckState.notStarted => ProfilePillTone.neutral,
  };
}
