import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/profile/domain/profile_completion.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';

/// What another person is allowed to see.
///
/// [legalFirstName] and [legalLastName] are kept for the owner record only.
/// Widgets in this file never paint them.
class PublicProfile {
  const PublicProfile({
    this.nickname = '',
    this.legalFirstName = '',
    this.legalLastName = '',
    this.photoRef,
    this.showPhotoToVerifiedUsers = false,
    this.viewerVerified = false,
    this.mobileVerified = false,
    this.emailVerified = false,
    this.identityVerified = false,
    this.selfieVerified = false,
  });

  final String nickname;
  final String legalFirstName;
  final String legalLastName;
  final String? photoRef;

  /// Off until the person opts in. The selfie stays private otherwise.
  final bool showPhotoToVerifiedUsers;

  /// True when the person looking at this profile has finished verification.
  final bool viewerVerified;
  final bool mobileVerified;
  final bool emailVerified;
  final bool identityVerified;
  final bool selfieVerified;

  static const verifiedDemo = PublicProfile(
    nickname: 'Verified member',
    mobileVerified: true,
    emailVerified: true,
    identityVerified: true,
    selfieVerified: true,
    viewerVerified: true,
  );

  String get publicName {
    final name = nickname.trim();
    return name.isEmpty ? 'Homizi member' : name;
  }

  bool get isVerified =>
      mobileVerified && emailVerified && identityVerified && selfieVerified;

  bool get showsPhoto {
    final photo = photoRef?.trim() ?? '';
    return showPhotoToVerifiedUsers && viewerVerified && photo.isNotEmpty;
  }

  List<String> get badges => [
    if (mobileVerified) 'Mobile Verified',
    if (emailVerified) 'Email Verified',
    if (identityVerified) 'Identity Verified',
    if (selfieVerified) 'Selfie Verified',
  ];

  PublicProfile copyWith({
    String? nickname,
    String? legalFirstName,
    String? legalLastName,
    String? photoRef,
    bool clearPhoto = false,
    bool? showPhotoToVerifiedUsers,
    bool? viewerVerified,
    bool? mobileVerified,
    bool? emailVerified,
    bool? identityVerified,
    bool? selfieVerified,
  }) {
    return PublicProfile(
      nickname: nickname ?? this.nickname,
      legalFirstName: legalFirstName ?? this.legalFirstName,
      legalLastName: legalLastName ?? this.legalLastName,
      photoRef: clearPhoto ? null : (photoRef ?? this.photoRef),
      showPhotoToVerifiedUsers:
          showPhotoToVerifiedUsers ?? this.showPhotoToVerifiedUsers,
      viewerVerified: viewerVerified ?? this.viewerVerified,
      mobileVerified: mobileVerified ?? this.mobileVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      identityVerified: identityVerified ?? this.identityVerified,
      selfieVerified: selfieVerified ?? this.selfieVerified,
    );
  }
}

PublicProfile publicProfileFromDraft(ProfileCreateDraft draft) {
  final verified =
      draft.mobileVerified &&
      draft.emailVerified &&
      draft.aadhaarVerified &&
      draft.selfieVerified;
  return PublicProfile(
    nickname: draft.nickname.trim(),
    legalFirstName: draft.firstName.trim(),
    legalLastName: draft.lastName.trim(),
    photoRef: draft.sampleAvatar,
    showPhotoToVerifiedUsers: draft.showPhotoToVerifiedUsers,
    viewerVerified: verified,
    mobileVerified: draft.mobileVerified,
    emailVerified: draft.emailVerified,
    identityVerified: draft.aadhaarVerified,
    selfieVerified: draft.selfieVerified,
  );
}

class ProfileVerificationBadges extends StatelessWidget {
  const ProfileVerificationBadges({required this.badges, super.key});

  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final badge in badges)
          Chip(
            key: Key('badge-$badge'),
            label: Text(homiziText(context, badge)),
            visualDensity: VisualDensity.compact,
            backgroundColor: profileVerifiedWash,
            side: const BorderSide(color: profileVerifiedGreen),
            labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

/// Nickname, initials or an opted-in photo, and only the checks that passed.
class PublicProfileCard extends StatelessWidget {
  const PublicProfileCard({required this.profile, super.key});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.publicName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profile.showsPhoto)
          ClipOval(
            child: SizedBox(
              key: const Key('public-profile-photo'),
              width: 72,
              height: 72,
              child: _photo(profile.photoRef!),
            ),
          )
        else
          CircleAvatar(
            key: const Key('public-profile-initials'),
            radius: 36,
            backgroundColor: HomiziColors.mist,
            foregroundColor: HomiziColors.ink,
            child: Text(
              profileInitials(name),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, name),
          key: const Key('public-profile-name'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (profile.badges.isNotEmpty) ...[
          const SizedBox(height: 8),
          ProfileVerificationBadges(badges: profile.badges),
        ],
      ],
    );
  }

  Widget _photo(String ref) {
    if (ref.startsWith('assets/')) {
      return Image.asset(
        ref,
        fit: BoxFit.cover,
        width: 72,
        height: 72,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.person, color: HomiziColors.muted),
      );
    }
    return const Icon(Icons.person, color: HomiziColors.muted);
  }
}
