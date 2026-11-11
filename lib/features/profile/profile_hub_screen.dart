import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/profile/avatar_actions.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/domain/profile_contact.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';
import 'package:homizi/features/profile/profile_page_model.dart';
import 'package:homizi/features/profile/profile_page_view.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_providers.dart';

export 'profile_page_model.dart' show ProfilePageRole, profilePageRoleFromQuery;

/// Profile tab. The layout follows the signed-in role.
///
/// Pass [previewRole] (or open `/profile/preview?role=`) to show one of the
/// four spec samples. Those samples are for screenshots. Aadhaar and the
/// selfie on a real profile stay unverified until Digio says they passed.
class ProfileHubScreen extends ConsumerStatefulWidget {
  const ProfileHubScreen({
    super.key,
    this.previewRole,
    this.showSpecNav = false,
  });

  final ProfilePageRole? previewRole;
  final bool showSpecNav;

  @override
  ConsumerState<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends ConsumerState<ProfileHubScreen> {
  TenantProfile _profile = const TenantProfile();
  HostProfile _host = const HostProfile();
  ProfileActivity _activity = ProfileActivity.empty;
  UserBadges _badges = const UserBadges();
  KycSnapshot _kyc = KycSnapshot.notStarted;
  List<OwnerListing> _listings = const [];
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.previewRole != null) {
      _loading = false;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final accounts = ref.read(accountGatewayProvider);
      final profile = await accounts.loadTenantProfile();
      final host = await _hostProfile(accounts);
      final activity = await _activityOrEmpty();
      final badges = await _badgesOrEmpty();
      final listings = await _listingsOrEmpty();
      final kyc = await _kycOrEmpty();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _host = host;
        _activity = activity;
        _badges = badges;
        _listings = listings;
        _kyc = kyc;
        _loading = false;
        _error = null;
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<HostProfile> _hostProfile(AccountGateway accounts) async {
    try {
      return await accounts.loadHostProfile();
    } on AccountFailure {
      return const HostProfile();
    }
  }

  Future<ProfileActivity> _activityOrEmpty() async {
    try {
      return await ref.read(profileHubGatewayProvider).loadActivity();
    } on ProfileHubFailure {
      return ProfileActivity.empty;
    }
  }

  Future<UserBadges> _badgesOrEmpty() async {
    try {
      return await ref.read(ownerGatewayProvider).myBadges();
    } on OwnerFailure {
      return const UserBadges();
    } on Object {
      return const UserBadges();
    }
  }

  Future<List<OwnerListing>> _listingsOrEmpty() async {
    try {
      return await ref.read(ownerGatewayProvider).myListings();
    } on OwnerFailure {
      return const [];
    } on Object {
      return const [];
    }
  }

  Future<KycSnapshot> _kycOrEmpty() async {
    try {
      return await ref.read(kycGatewayProvider).current();
    } on Object {
      return KycSnapshot.notStarted;
    }
  }

  ProfilePageRole? _forced(BuildContext context) {
    if (widget.previewRole != null) {
      return widget.previewRole;
    }
    try {
      return profilePageRoleFromQuery(
        GoRouterState.of(context).uri.queryParameters['preview'],
      );
    } on Object {
      return null;
    }
  }

  ProfilePageRole _role(ProfilePageRole? forced) {
    if (forced != null) {
      return forced;
    }
    return switch (ref.watch(currentRoleProvider)) {
      HomiziRole.host => ProfilePageRole.owner,
      HomiziRole.broker => ProfilePageRole.broker,
      HomiziRole.roommate => ProfilePageRole.roomie,
      HomiziRole.tenant || null => ProfilePageRole.tenant,
    };
  }

  void _open(String route, {bool go = false}) {
    if (route.isEmpty) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    if (go) {
      router.go(route);
      return;
    }
    router.push(route);
  }

  void _share() {
    openDemoSuccess(
      context,
      title: 'Profile link ready',
      detail: 'Your phone number stays hidden.',
    );
  }

  void _preview(ProfilePageModel model) {
    final verification = ref.read(ownVerificationProvider);
    final shown = verification.copyWith(
      nickname: verification.nickname.trim().isEmpty
          ? model.name
          : verification.nickname,
      viewerVerified: verification.isVerified,
      photoRef: verification.photoRef ?? _profile.avatarUrl,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ProfileHostPreviewPage(profile: shown),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forced = _forced(context);
    final illustration = forced != null;
    final session = ref.watch(sessionProvider);
    final own = ref.watch(ownVerificationProvider);
    final role = _role(forced);
    final model = resolveProfilePage(
      ProfilePageInput(
        role: role,
        illustration: illustration,
        profile: _profile,
        host: _host,
        activity: _activity,
        badges: _badges,
        kyc: _kyc,
        own: own,
        contact: shownContact(session.contact),
        listings: _listings,
      ),
    );
    return MinTouchScope(
      child: RepaintBoundary(
        key: const Key('profile-shot'),
        child: ProfilePageView(
          model: model,
          showSpecNav: widget.showSpecNav,
          notice: _loading ? null : _error,
          onRefresh: illustration ? null : _load,
          onOpen: _open,
          onShare: _share,
          onHostPreview: () => _preview(model),
          avatar: illustration
              ? null
              : ProfilePhotoRow(
                  name: model.name,
                  photoRef: _profile.avatarUrl,
                  gateway: ref.read(accountGatewayProvider),
                  centered: true,
                  onSaved: (next) => setState(() {
                    _profile = next == null
                        ? _profile.copyWith(clearAvatar: true)
                        : _profile.copyWith(avatarUrl: next);
                  }),
                ),
        ),
      ),
    );
  }
}
