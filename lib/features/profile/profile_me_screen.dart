import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/engagement_row.dart';
import 'package:homizi/core/widgets/homizi_date_field.dart';
import 'package:homizi/core/widgets/homizi_home_bar.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/saved_summary.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/matches/mutual_matches.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/office/saved_office_field.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/profile/animated_profile_photo.dart';
import 'package:homizi/features/profile/avatar_actions.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/edit_profile_screen.dart';
import 'package:homizi/features/profile/occupation_picker.dart';
import 'package:homizi/features/profile/profile_dashboard_model.dart';
import 'package:homizi/features/profile/profile_gaps_screen.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';
import 'package:homizi/features/profile/profile_photo_viewer.dart';
import 'package:homizi/features/profile/profile_section_page.dart';
import 'package:homizi/features/profile/verification_panel.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/publish/published_activity.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/session/log_out.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_providers.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Signed-in profile dashboard. The Profile tab and `/profile/me`.
class ProfileMeScreen extends ConsumerStatefulWidget {
  const ProfileMeScreen({super.key});

  @override
  ConsumerState<ProfileMeScreen> createState() => _ProfileMeScreenState();
}

class _ProfileMeScreenState extends ConsumerState<ProfileMeScreen> {
  TenantProfile _profile = const TenantProfile();
  ProfileActivity _activity = ProfileActivity.empty;
  KycSnapshot _kyc = KycSnapshot.notStarted;
  List<OwnerListing> _listings = const [];
  ProfileCreateDraft _draft = const ProfileCreateDraft();
  String? _error;
  var _tab = 0;
  var _switching = false;
  var _hostCreated = false;
  var _hasOffice = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    final store = ref.read(profileCreateStoreProvider);
    _draft = await store.hydrate(store.draft);
    try {
      final profile = await ref
          .read(accountGatewayProvider)
          .loadTenantProfile();
      if (!mounted) {
        return;
      }
      setState(() => _profile = profile);
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = error.message);
    }
    try {
      final activity = await ref.read(profileHubGatewayProvider).loadActivity();
      if (mounted) {
        setState(() => _activity = activity);
      }
    } on ProfileHubFailure {
      if (mounted) {
        setState(() => _activity = ProfileActivity.empty);
      }
    } on Object {
      if (mounted) {
        setState(() => _activity = ProfileActivity.empty);
      }
    }
    try {
      final kyc = await ref.read(kycGatewayProvider).current();
      if (mounted) {
        setState(() => _kyc = kyc);
      }
    } on Object {
      if (mounted) {
        setState(() => _kyc = KycSnapshot.comingSoon);
      }
    }
    try {
      await ref.read(officeRepositoryProvider).load();
      if (mounted) {
        setState(() {
          _hasOffice = ref.read(officeRepositoryProvider).offices.isNotEmpty;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _hasOffice = false);
      }
    }
    try {
      final hostProfile = await ref
          .read(accountGatewayProvider)
          .loadHostProfile();
      if (mounted) {
        setState(() => _hostCreated = hostProfile.created);
      }
    } on Object {
      if (mounted) {
        setState(() => _hostCreated = false);
      }
    }
    try {
      final listings = await ref.read(ownerGatewayProvider).myListings();
      if (mounted) {
        setState(() => _listings = listings);
      }
    } on OwnerFailure {
      if (mounted) {
        setState(() => _listings = const []);
      }
    } on Object {
      if (mounted) {
        setState(() => _listings = const []);
      }
    }
  }

  Future<void> _createHostProfile() async {
    await context.push(RoutePaths.hostProfile);
    if (!mounted) {
      return;
    }
    await _load();
  }

  Future<void> _switchRole() async {
    final current = ref.read(currentRoleProvider)?.name;
    final next = profileSwitchTarget(current);
    setState(() => _switching = true);
    final message = await ref
        .read(sessionProvider.notifier)
        .selectPrimaryRole(next);
    if (!mounted) {
      return;
    }
    setState(() => _switching = false);
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _save(ProfileCreateDraft next) async {
    setState(() => _draft = next);
    await ref.read(profileCreateStoreProvider).save(next);
  }

  Future<void> _commit(ProfileCreateDraft next) async {
    await _save(next);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(homiziText(context, 'Saved')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _openSection({
    required String title,
    required Widget child,
    GlobalKey? revealKey,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => ProfileSectionPage(
          title: title,
          revealKey: revealKey,
          child: child,
        ),
      ),
    );
    return saved == true;
  }

  ProfileCompleteness _score() {
    final session = ref.read(sessionProvider);
    final wire =
        ref.read(currentRoleProvider)?.name ?? profilePrimaryWire(_draft);
    final requirement = ref.read(savedRequirementProvider).asData?.value;
    final signedInEmail = session.contact.contains('@')
        ? session.contact.trim()
        : '';
    final draft = _draft.email.trim().isEmpty && signedInEmail.isNotEmpty
        ? _draft.copyWith(email: signedInEmail)
        : _draft;
    return profileWizardCompleteness(
      draft: draft,
      profile: _profile,
      aadhaarVerified: _aadhaarVerified,
      phoneVerified: session.phoneVerified || _draft.mobileVerified,
      emailVerified: session.emailVerified || _draft.emailVerified,
      roleWire: wire,
      hasOffice: _hasOffice || _draft.companyName.trim().isNotEmpty,
      prioritiesSaved: ref.read(searchPrioritiesProvider).saved,
      roommateSaved: requirement != null,
    );
  }

  Future<void> _openMissing() async {
    final score = _score();
    if (score.gaps.isEmpty) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => ProfileGapsScreen(
          readScore: _score,
          onOpen: (gap) async {
            await _openGap(gap);
          },
        ),
      ),
    );
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openGap(ProfileGap? gap) async {
    final missing = gap;
    if (missing == null) {
      return;
    }
    switch (missing.field) {
      case 'photo':
        await _changePhoto();
      case 'bio':
        await _editAbout();
      case 'phone':
        await context.push('${RoutePaths.verifyContact}?channel=phone');
      case 'email':
        await _editEmail();
      case 'office':
        await context.push(RoutePaths.office);
        await ref.read(officeRepositoryProvider).load();
        if (mounted) {
          setState(() {
            _hasOffice = ref.read(officeRepositoryProvider).offices.isNotEmpty;
          });
        }
      case 'priorities':
        await context.push(RoutePaths.priorities);
      case 'roommate':
        await _editRequirements();
      case 'name':
        await _editNickname();
      case 'smoking':
        await _editLifestyle();
      case 'languages':
        await _editLanguages();
      default:
        await _editBasic(focus: missing.field);
    }
  }

  Future<void> _editEmail() async {
    final sessionEmail = ref.read(sessionProvider).contact.trim();
    final email = TextEditingController(
      text: _draft.email.trim().isNotEmpty
          ? _draft.email
          : (sessionEmail.contains('@') ? sessionEmail : ''),
    );
    final saved = await _openSection(
      title: 'Email',
      child: KitTextField(
        fieldKey: const Key('profile-edit-email'),
        label: 'Email',
        controller: email,
        hint: 'you@email.com',
        icon: RealLifeIcons.badge,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
      ),
    );
    if (saved == true) {
      await _commit(_draft.copyWith(email: email.text.trim()));
    }
    email.dispose();
  }

  bool get _aadhaarVerified => _kyc.aadhaarVerified || _draft.aadhaarVerified;

  @override
  Widget build(BuildContext context) {
    reloadWhenUserChanges(ref, () => unawaited(_load()));
    ref.watch(sessionProvider);
    ref.watch(searchPrioritiesProvider);
    ref.watch(savedRequirementProvider);
    ref.watch(officeRevisionProvider);
    final wire =
        ref.watch(currentRoleProvider)?.name ?? profilePrimaryWire(_draft);
    final host = profileHostSide(wire);
    final stats = profileDashboardStats(_activity);
    final score = _score();
    final name = _displayName();
    final media = ref.watch(profileMediaProvider);
    return RepaintBoundary(
      key: const Key('profile-me-shot'),
      child: Scaffold(
        key: const Key('profile-me-screen'),
        backgroundColor: HomiziColors.white,
        appBar: HomiziHomeBar(
          profileKey: const Key('profile-me-avatar'),
          actions: [
            IconButton(
              key: const Key('profile-me-bell'),
              tooltip: homiziText(context, 'Notifications'),
              onPressed: () => context.push(RoutePaths.notifications),
              icon: const Icon(Icons.notifications_none),
            ),
          ],
        ),
        body: PageBackground(
          variant: PageBackgroundVariant.soft,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (_error != null)
                  _panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          homiziText(context, _error!),
                          key: const Key('profile-me-error'),
                        ),
                        TextButton(
                          key: const Key('profile-me-retry'),
                          onPressed: () => unawaited(_load()),
                          child: Text(homiziText(context, 'Try again')),
                        ),
                      ],
                    ),
                  ),
                _header(name, wire, host, media.photo, stats, score),
                const SizedBox(height: 8),
                _tabs(host),
                const SizedBox(height: 12),
                switch (_tab) {
                  1 => _preferences(host),
                  2 => _listingsPane(host),
                  3 => _activityPane(),
                  4 => _verification(),
                  _ => _myProfile(host),
                },
                const LogOutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _displayName() {
    final fromDraft = profilePublicName(_draft).trim();
    if (fromDraft.length >= 2) {
      return fromDraft;
    }
    final stored = _profile.displayName.trim();
    if (stored.isNotEmpty) {
      return stored;
    }
    return 'Your profile';
  }

  String? get _photoRef {
    final own = _profile.avatarUrl?.trim() ?? '';
    if (own.isNotEmpty && !isListingPhotoPath(own)) {
      return own;
    }
    final sample = _draft.sampleAvatar?.trim() ?? '';
    if (sample.isNotEmpty && !isListingPhotoPath(sample)) {
      return sample;
    }
    return null;
  }

  String get _aboutText {
    final draft = _draft.about.trim();
    if (draft.isNotEmpty) {
      return draft;
    }
    return _profile.bio.trim();
  }

  void _applyPhoto(String? next) {
    final media = ref.read(profileMediaProvider.notifier);
    if (next != null && next.startsWith('data:')) {
      final comma = next.indexOf(',');
      if (comma > 0) {
        try {
          media.setPhoto(base64Decode(next.substring(comma + 1)));
        } on Object {
          media.clearPhoto();
        }
      }
    } else {
      media.clearPhoto();
    }
    setState(() {
      _profile = _profile.copyWith(avatarUrl: next, clearAvatar: next == null);
    });
  }

  Future<void> _changePhoto() {
    return chooseProfilePhoto(
      context: context,
      gateway: ref.read(accountGatewayProvider),
      photoRef: _photoRef,
      onSaved: _applyPhoto,
    );
  }

  void _openOwnPhoto() {
    openProfilePhotoViewer(
      context: context,
      heroTag: ownProfilePhotoHero,
      name: _displayName(),
      bytes: ref.read(profileMediaProvider).photo,
      photoRef: _photoRef,
      onChangePhoto: () => unawaited(_changePhoto()),
    );
  }

  Future<void> _openEdit() async {
    final next = await Navigator.of(context).push<ProfileCreateDraft>(
      MaterialPageRoute<ProfileCreateDraft>(
        builder: (context) => EditProfileScreen(
          draft: _draft,
          name: _displayName(),
          photoBytes: ref.read(profileMediaProvider).photo,
          photoRef: _photoRef,
          verified: _aadhaarVerified,
          onPhotoSaved: _applyPhoto,
        ),
      ),
    );
    if (next == null) {
      return;
    }
    await _commit(next);
  }

  Widget _header(
    String name,
    String? wire,
    bool host,
    Uint8List? photo,
    ProfileDashboardStats stats,
    ProfileCompleteness score,
  ) {
    final about = _aboutText;
    final createHost = !host && !_hostCreated;
    final nextRole = host ? 'Tenant' : 'Host';
    final roleLabel = createHost
        ? 'Create profile as host'
        : (_switching ? 'Switching…' : 'Switch to $nextRole');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnimatedProfilePhoto(
              key: const Key('profile-photo'),
              name: name,
              bytes: photo,
              photoRef: _photoRef,
              heroTag: ownProfilePhotoHero,
              onTap: _openOwnPhoto,
            ),
            const SizedBox(width: 12),
            Expanded(child: _stats(stats)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                key: const Key('profile-name'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (_aadhaarVerified) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.verified,
                key: Key('profile-me-verified'),
                color: HomiziColors.success,
                size: 20,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Container(
          key: const Key('profile-me-role'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: const BoxDecoration(
            color: HomiziColors.accentWash,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Text(
            homiziText(context, profileRoleChip(wire)),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (about.isEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('profile-add-bio'),
              onPressed: () => unawaited(_editAbout()),
              icon: const Icon(
                Icons.edit_outlined,
                color: HomiziColors.logoOrange,
              ),
              label: Text(
                homiziText(context, 'Add a bio'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: HomiziColors.logoOrange,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          )
        else
          Text(
            about,
            key: const Key('profile-bio'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: HomiziColors.ink,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextButton(
                key: const Key('profile-edit-basic'),
                style: TextButton.styleFrom(
                  backgroundColor: HomiziColors.soft,
                  foregroundColor: HomiziColors.ink,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                onPressed: () => unawaited(_openEdit()),
                child: Text(
                  homiziText(context, 'Edit profile'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton.icon(
                key: const Key('profile-role-switch'),
                style: TextButton.styleFrom(
                  backgroundColor: HomiziColors.soft,
                  foregroundColor: HomiziColors.ink,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
                onPressed: _switching
                    ? null
                    : () => unawaited(
                        createHost ? _createHostProfile() : _switchRole(),
                      ),
                icon: Icon(
                  createHost ? Icons.add_home_outlined : Icons.swap_horiz,
                  color: HomiziColors.ink,
                ),
                label: Text(
                  homiziText(context, roleLabel),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _completeness(score),
      ],
    );
  }

  Widget _stats(ProfileDashboardStats stats) {
    return Row(
      children: [
        _stat(
          'Matches',
          stats.matches,
          'profile-stat-matches',
          () => context.push(RoutePaths.matches),
        ),
        _stat(
          'Saved',
          stats.saved,
          'profile-stat-saved',
          () => context.push(RoutePaths.saved),
        ),
        _stat(
          'Views',
          stats.views,
          'profile-stat-views',
          () => context.push(RoutePaths.recentlyViewed),
        ),
        _stat(
          'Inquiries',
          stats.inquiries,
          'profile-stat-inquiries',
          () => context.push(RoutePaths.profileInquiries),
        ),
      ],
    );
  }

  Widget _stat(String label, int value, String key, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        key: Key('$key-open'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Text(
                '$value',
                key: Key(key),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.ink,
                  fontSize: 18,
                ),
              ),
              Text(
                homiziText(context, label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _completeness(ProfileCompleteness score) {
    final done = score.complete;
    final color = done ? HomiziColors.success : HomiziColors.logoOrange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(99)),
          child: LinearProgressIndicator(
            value: score.percent / 100,
            minHeight: 4,
            color: color,
            backgroundColor: done
                ? HomiziColors.successWash
                : HomiziColors.line,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '${score.percent}%',
              key: const Key('profile-completeness'),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                homiziText(context, score.line),
                key: done ? const Key('profile-complete-state') : null,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: done ? HomiziColors.success : HomiziColors.muted,
                  fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            if (done)
              const Icon(
                Icons.check_circle,
                color: HomiziColors.success,
                size: 18,
                key: Key('profile-complete-mark'),
              )
            else
              TextButton(
                key: const Key('profile-complete-now'),
                onPressed: () => unawaited(_openMissing()),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: HomiziColors.logoOrange,
                ),
                child: Text(
                  homiziText(context, 'Complete Now'),
                  style: const TextStyle(
                    color: HomiziColors.logoOrange,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _tabs(bool host) {
    final tabs = <(String, IconData)>[
      ('My Profile', Icons.person_outline),
      ('Preferences', Icons.interests),
      (
        host ? 'My Listings' : 'Saved',
        host ? Icons.apartment_outlined : Icons.favorite_border,
      ),
      ('Activity', Icons.history),
      ('Verification', Icons.verified_outlined),
    ];
    return Column(
      children: [
        const Divider(height: 1, thickness: 0.5, color: HomiziColors.line),
        Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: Tooltip(
                  message: homiziText(context, tabs[i].$1),
                  child: GestureDetector(
                    key: Key('profile-tab-${tabs[i].$1}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _tab = i),
                    child: SizedBox(
                      height: 46,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            tabs[i].$2,
                            size: 24,
                            color: _tab == i
                                ? HomiziColors.logoOrange
                                : HomiziColors.muted,
                          ),
                          const SizedBox(height: 8),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 2,
                            width: _tab == i ? 36 : 0,
                            color: HomiziColors.logoOrange,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _myProfile(bool host) {
    final birth = profileBirthLabel(_draft) ?? 'Add your date of birth';
    final occupation = (_draft.occupation ?? _profile.occupation).trim();
    final about = _draft.about.trim().isNotEmpty
        ? _draft.about.trim()
        : _profile.bio.trim();
    return Column(
      children: [
        _accountCard(),
        _section(
          title: 'Basic Information',
          editKey: 'profile-edit-basic-card',
          onEdit: () => unawaited(_editBasic()),
          child: Column(
            children: [
              _row('Full Name', _legalOrPrivate()),
              _row('Date of Birth', birth),
              _row(
                'Occupation',
                occupation.isEmpty ? 'Add your occupation' : occupation,
              ),
              _row(
                'Company',
                _draft.companyName.trim().isEmpty
                    ? 'Add your company'
                    : _draft.companyName.trim(),
              ),
              _row(
                'Current City',
                _draft.city.trim().isEmpty ? 'Add your city' : _draft.city,
              ),
              const SavedOfficeField(compact: true),
            ],
          ),
        ),
        _section(
          title: 'About Me',
          editKey: 'profile-edit-about',
          onEdit: () => unawaited(_editAbout()),
          child: about.isEmpty
              ? Text(
                  homiziText(context, 'Tell people a little about you.'),
                  key: const Key('profile-about-empty'),
                )
              : Text(about),
        ),
        if (_draft.tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              children: [for (final tag in _draft.tags) Chip(label: Text(tag))],
            ),
          ),
        _lifestyleCard(),
        _prioritiesEntry(),
        if (host) _hostNote() else _requirements(),
        _documents(),
      ],
    );
  }

  Widget _preferences(bool host) {
    final config = ref.watch(appConfigProvider);
    final discovery = ref.watch(discoveryProvider);
    final demoMode =
        !config.connectsToSupabase ||
        ref.watch(forceDemoModeProvider) ||
        config.demoSkipLogin;
    final matches = mutualMatchRows(
      discovery: discovery,
      demoMode: demoMode,
      roomieLikedIds: const {},
    );
    final lines = <String>[
      'Smoking: ${_draft.smoking ?? 'Add'}',
      'Drinking: ${_draft.drinking ?? 'Add'}',
      'Food: ${_draft.food ?? 'Add'}',
      if (_draft.languages.isNotEmpty)
        'Languages: ${_draft.languages.join(', ')}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SavedSummaryCard(
          title: 'Preferences saved ✓',
          lines: lines,
          onEdit: () => unawaited(_editLifestyle()),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('profile-edit-languages-link'),
            onPressed: () => unawaited(_editLanguages()),
            child: Text(
              homiziText(context, 'Edit languages'),
              style: const TextStyle(
                color: HomiziColors.logoOrange,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Text(
          homiziText(context, 'Matches'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          Text(
            homiziText(context, 'No matches yet.'),
            key: const Key('profile-matches-empty'),
          )
        else
          for (final match in matches)
            EngagementRow(
              title: match.otherDisplayName,
              subtitle: match.listingTitle ?? 'Mutual match',
              photoRef: match.avatarUrl,
              person: true,
              onTap: () => context.push(
                RoutePaths.chat(
                  match.matchId,
                  name: match.otherDisplayName,
                  title: match.listingTitle,
                  otherUserId: match.otherUserId,
                  avatar: match.avatarUrl,
                ),
              ),
            ),
        if (!host) _requirements(),
      ],
    );
  }

  Widget _listingsPane(bool host) {
    if (!host) {
      final discovery = ref.watch(discoveryProvider);
      final homes = <Listing>[
        for (final id in discovery.likedIds) ?discovery.byId(id),
      ];
      if (homes.isEmpty) {
        return _panel(
          child: Text(
            homiziText(context, 'Homes you like show up here.'),
            key: const Key('profile-saved-homes-empty'),
          ),
        );
      }
      return Column(
        children: [
          for (final home in homes)
            EngagementRow(
              title: home.title,
              subtitle: '${home.locality}, ${home.city}',
              price: formatInr(home.rentInr),
              photoRef: home.hostAvatarUrl,
              thumbnailRef: home.photoAssets.isEmpty
                  ? null
                  : home.photoAssets.first,
              person: true,
              highlights: homeHighlightIcons(
                bhk: home.bhkLabel,
                furnishing: home.furnishingLabel,
                parking: home.parking,
                pets: home.petsAllowed,
                vegOnly: !home.nonVegAllowed,
              ),
              onTap: () => context.push('/listing/${home.id}'),
            ),
        ],
      );
    }
    if (_listings.isEmpty) {
      return _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, 'You have no listings yet.'),
              key: const Key('profile-listings-empty'),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(context, 'Add a home when you are ready to list it.'),
            ),
            TextButton(
              key: const Key('profile-add-listing'),
              onPressed: () => context.push(RoutePaths.listingEditor),
              child: Text(
                homiziText(context, 'Add a listing'),
                style: const TextStyle(
                  color: HomiziColors.logoOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('profile-add-listing'),
            onPressed: () => context.push(RoutePaths.listingEditor),
            child: Text(
              homiziText(context, 'Add a listing'),
              style: const TextStyle(
                color: HomiziColors.logoOrange,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        _ListingGrid(listings: _listings, coverFor: _listingCover),
      ],
    );
  }

  String? _listingCover(OwnerListing listing) {
    final photos = ref
        .read(demoListingMemoryProvider)
        .byId(listing.id)
        ?.draft
        .photos;
    if (photos == null || photos.isEmpty) {
      return null;
    }
    return assetForPhoto(photos.first);
  }

  Widget _activityPane() {
    final published = ref.watch(publishedActivityProvider);
    if (_activity.matchCount == 0 &&
        _activity.savedCount == 0 &&
        _activity.viewedCount == 0 &&
        _activity.requestCount == 0 &&
        published.isEmpty) {
      return _panel(
        child: Text(
          homiziText(context, 'No activity yet.'),
          key: const Key('profile-activity-empty'),
        ),
      );
    }
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PublishedActivitySection(),
          _row('Matches', '${_activity.matchCount}'),
          for (final match in _activity.matches) Text(match.name),
          const SizedBox(height: 8),
          _row('Saved', '${_activity.savedCount}'),
          for (final place in _activity.saved)
            Text('${place.title} · ${place.place}'),
          const SizedBox(height: 8),
          _row(
            'Views',
            _activity.viewedAvailable ? '${_activity.viewedCount}' : '0',
          ),
          _row('Inquiries', '${_activity.requestCount}'),
        ],
      ),
    );
  }

  Widget _verification() {
    final session = ref.watch(sessionProvider);
    return VerificationPanel(
      emailVerified: session.emailVerified || _draft.emailVerified,
      phoneVerified: session.phoneVerified || _draft.mobileVerified,
      aadhaarVerified: _aadhaarVerified,
      onEmail: session.emailVerified
          ? null
          : () => context.push('${RoutePaths.verifyContact}?channel=email'),
      onPhone: session.phoneVerified
          ? null
          : () => context.push('${RoutePaths.verifyContact}?channel=phone'),
      onAadhaar: () => context.push(RoutePaths.verifyIdentity),
    );
  }

  Widget _lifestyleCard() {
    return _section(
      title: 'Lifestyle & Preferences',
      editKey: 'profile-edit-lifestyle',
      onEdit: () => unawaited(_editLifestyle()),
      child: Column(
        children: [
          _row('Smoking', _draft.smoking ?? 'Add'),
          _row('Drinking', _draft.drinking ?? 'Add'),
          _row('Food', _draft.food ?? 'Add'),
          _row('Cooking', _draft.cooking ?? 'Add'),
          _row('Cleaning', _draft.cleaning ?? 'Add'),
          _row('Pets', _draft.pets ?? 'Add'),
        ],
      ),
    );
  }

  Widget _requirements() {
    final budget = _budgetLabel();
    final places = _draft.localities.isNotEmpty
        ? _draft.localities.join(', ')
        : _profile.preferences.localities.join(', ');
    final looking = _draft.lookingFor.isEmpty
        ? 'Add what you are looking for'
        : _draft.lookingFor.map(tenantPropertyTypeLabel).join(' / ');
    return _section(
      title: 'My Requirements as Tenant',
      editKey: 'profile-edit-requirements',
      onEdit: () => unawaited(_editRequirements()),
      child: Column(
        children: [
          _row('Looking for', looking),
          _row('Budget', budget),
          _row(
            'Preferred Location',
            places.isEmpty ? 'Add localities' : places,
          ),
          _row(
            'Move-in Date',
            _draft.moveInLabel.trim().isEmpty
                ? 'Add a move-in date'
                : _draft.moveInLabel,
          ),
        ],
      ),
    );
  }

  Widget _prioritiesEntry() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HomiziColors.white,
        child: ListTile(
          key: const Key('profile-my-priorities'),
          title: Text(
            homiziText(context, 'My Priorities'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            homiziText(context, 'Set the order that decides your matches.'),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(RoutePaths.priorities),
        ),
      ),
    );
  }

  String _budgetLabel() {
    final min = _draft.budgetMin ?? _profile.preferences.budgetMinInr;
    final max = _draft.budgetMax ?? _profile.preferences.budgetMaxInr;
    if (min == null && max == null) {
      return 'Add a budget';
    }
    String rupee(int? value) => value == null ? '' : '₹ $value';
    if (min != null && max != null) {
      return '${rupee(min)} – ${rupee(max)} / month';
    }
    return '${rupee(min ?? max)} / month';
  }

  Widget _hostNote() {
    return _panel(
      child: Text(
        homiziText(
          context,
          'For Property Owner / Host / Property Partner: Profile setup is complete after verification.',
        ),
      ),
    );
  }

  Widget _documents() {
    final aadhaar = _aadhaarVerified;
    return _section(
      title: 'Documents',
      editKey: 'profile-add-document',
      onEdit: () => unawaited(_addDocument()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (aadhaar)
            const ProfileCheckLine(
              label: 'Aadhaar Card',
              color: profileVerifiedGreen,
              iconKey: Key('profile-doc-aadhaar'),
            )
          else
            Text(
              homiziText(
                context,
                'Aadhaar stays unverified until Digio confirms it.',
              ),
            ),
          for (final name in _draft.documents)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(name)),
          if (_draft.documents.isEmpty && !aadhaar)
            Text(
              homiziText(context, 'No documents yet.'),
              key: const Key('profile-documents-empty'),
            ),
        ],
      ),
    );
  }

  Widget _accountCard() {
    final session = ref.watch(sessionProvider);
    final email = session.contact.contains('@')
        ? session.contact.trim()
        : _draft.email.trim();
    final phone = session.phoneE164.trim().isNotEmpty
        ? session.phoneE164.trim()
        : _draft.mobile.trim();
    final emailVerified = session.emailVerified || _draft.emailVerified;
    final phoneVerified = session.phoneVerified || _draft.mobileVerified;
    return _section(
      title: 'Account details',
      editKey: 'profile-edit-account',
      onEdit: () => unawaited(_editNickname()),
      child: Column(
        children: [
          _locked('First name', _draft.firstName),
          _locked('Last name', _draft.lastName),
          _locked('Email', email, verified: emailVerified && email.isNotEmpty),
          _locked('Phone', phone, verified: phoneVerified && phone.isNotEmpty),
          _row(
            'Nickname',
            _draft.nickname.trim().isEmpty
                ? 'Add a nickname'
                : _draft.nickname.trim(),
          ),
        ],
      ),
    );
  }

  Widget _locked(String label, String value, {bool verified = false}) {
    final shown = value.trim().isEmpty ? 'Not added' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              homiziText(context, label),
              style: const TextStyle(color: HomiziColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              homiziText(context, shown),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (verified)
            const Icon(Icons.verified, color: HomiziColors.success, size: 18),
        ],
      ),
    );
  }

  String _legalOrPrivate() {
    final legal = [
      _draft.firstName.trim(),
      _draft.lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    if (legal.isEmpty) {
      return 'Full name stays private. Add it in Edit Profile.';
    }
    return legal;
  }

  Future<void> _editNickname() async {
    final nick = TextEditingController(text: _draft.nickname);
    final saved = await _openSection(
      title: 'Account details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _locked('First name', _draft.firstName),
          _locked('Last name', _draft.lastName),
          Text(
            homiziText(
              context,
              'First name, last name, and verified contact stay read-only.',
            ),
            style: const TextStyle(color: HomiziColors.muted),
          ),
          const SizedBox(height: 12),
          KitTextField(
            fieldKey: const Key('profile-edit-nick'),
            label: 'Nickname',
            controller: nick,
            hint: 'Asha',
            icon: RealLifeIcons.badge,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
          ),
        ],
      ),
    );
    if (saved == true) {
      await _commit(_draft.copyWith(nickname: nick.text.trim()));
    }
    nick.dispose();
  }

  Future<void> _editBasic({String focus = ''}) async {
    final company = TextEditingController(text: _draft.companyName);
    final city = TextEditingController(text: _draft.city);
    final day = TextEditingController(
      text: _draft.birthDay == null ? '' : '${_draft.birthDay}',
    );
    final month = TextEditingController(
      text: _draft.birthMonth == null ? '' : '${_draft.birthMonth}',
    );
    final year = TextEditingController(
      text: _draft.birthYear == null ? '' : '${_draft.birthYear}',
    );
    var occupation = _draft.occupation;
    var gender = _draft.gender;
    var pickedCity = _draft.city.trim();
    final reveal = GlobalKey();
    Widget pin(String field, Widget child) {
      if (focus != field) {
        return child;
      }
      return KeyedSubtree(key: reveal, child: child);
    }

    final saved = await _openSection(
      title: 'Basic Information',
      revealKey: focus.isEmpty ? null : reveal,
      child: StatefulBuilder(
        builder: (context, setLocal) {
          return Column(
            children: [
              pin(
                'birth',
                Row(
                  children: [
                    Expanded(
                      child: KitTextField(
                        label: 'Day',
                        controller: day,
                        hint: 'DD',
                        autofocus: focus == 'birth',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: KitTextField(
                        label: 'Month',
                        controller: month,
                        hint: 'MM',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: KitTextField(
                        label: 'Year',
                        controller: year,
                        hint: 'YYYY',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ),
              pin(
                'gender',
                KitChoiceField<String>(
                  label: 'Gender',
                  selected: gender,
                  options: [
                    for (final option in profileGenderOptions)
                      KitOption(value: option, label: option),
                  ],
                  onChanged: (value) => setLocal(() => gender = value),
                ),
              ),
              pin(
                'occupation',
                OccupationPicker(
                  selected: occupation,
                  onSelected: (value) => setLocal(() => occupation = value),
                ),
              ),
              KitTextField(
                label: 'Company',
                controller: company,
                hint: 'Homizi Studio',
                icon: RealLifeIcons.briefcase,
                textCapitalization: TextCapitalization.words,
              ),
              pin(
                'city',
                PlaceAutocompleteField(
                  fieldKey: const Key('profile-edit-city'),
                  controller: city,
                  labelText: 'Current City',
                  hintText: 'Bengaluru',
                  prefixIcon: const Icon(
                    RealLifeIcons.pin,
                    color: HomiziColors.logoOrange,
                  ),
                  stackedLabel: true,
                  pickOnly: true,
                  includedPrimaryTypes: const ['locality'],
                  textCapitalization: TextCapitalization.words,
                  onSelected: (place) {
                    if (place.manual ||
                        (!place.hasCoordinates &&
                            (place.placeId ?? '').isEmpty)) {
                      return;
                    }
                    final name = (place.city ?? place.label).trim();
                    if (name.isEmpty) {
                      return;
                    }
                    pickedCity = name;
                    city.text = name;
                    if (place.hasCoordinates) {
                      unawaited(
                        writeDeviceString(
                          'flutter.homizi.profile_place',
                          jsonEncode({
                            'label': place.label,
                            'latitude': place.latitude,
                            'longitude': place.longitude,
                          }),
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) {
      int? part(TextEditingController controller, int? current) {
        final parsed = int.tryParse(controller.text.trim());
        return parsed ?? current;
      }

      await _commit(
        _draft.copyWith(
          companyName: company.text.trim(),
          city: pickedCity,
          occupation: occupation,
          gender: gender,
          birthDay: part(day, _draft.birthDay),
          birthMonth: part(month, _draft.birthMonth),
          birthYear: part(year, _draft.birthYear),
        ),
      );
    }
    company.dispose();
    city.dispose();
    day.dispose();
    month.dispose();
    year.dispose();
  }

  Future<void> _editAbout() async {
    final about = TextEditingController(text: _aboutText);
    final tags = TextEditingController(text: _draft.tags.join(', '));
    final saved = await _openSection(
      title: 'About Me',
      child: Column(
        children: [
          KitTextField(
            fieldKey: const Key('profile-edit-about-field'),
            label: 'Bio',
            controller: about,
            hint: 'Quiet on weeknights. I cook most evenings.',
            icon: RealLifeIcons.lifestyle,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
          KitTextField(
            label: 'Tags',
            controller: tags,
            hint: 'Early riser, cook, reader',
            helper: 'Separate tags with commas.',
            icon: RealLifeIcons.badge,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
    if (saved == true) {
      await _commit(
        _draft.copyWith(
          about: about.text.trim(),
          tags: [
            for (final tag in tags.text.split(','))
              if (tag.trim().isNotEmpty) tag.trim(),
          ],
        ),
      );
    }
  }

  Future<void> _editLifestyle() async {
    var smoking = _draft.smoking;
    var drinking = _draft.drinking;
    var food = _draft.food;
    var cooking = _draft.cooking;
    var cleaning = _draft.cleaning;
    var pets = _draft.pets;
    final saved = await _openSection(
      title: 'Lifestyle & Preferences',
      child: StatefulBuilder(
        builder: (context, setLocal) {
          Widget menu(
            String label,
            String? value,
            List<String> options,
            ValueChanged<String?> onChanged,
          ) {
            return KitChoiceField<String>(
              label: label,
              icon: iconForChoice(label),
              selected: value,
              options: [
                for (final option in options)
                  KitOption(
                    value: option,
                    label: option,
                    icon: iconForChoice(option),
                  ),
              ],
              onChanged: (next) => setLocal(() => onChanged(next)),
            );
          }

          return Column(
            children: [
              menu('Smoking', smoking, profileSmokingOptions, (v) {
                smoking = v;
              }),
              menu('Drinking', drinking, profileDrinkingOptions, (v) {
                drinking = v;
              }),
              menu('Food', food, profileFoodOptions, (v) => food = v),
              menu('Cooking', cooking, profileCookingOptions, (v) {
                cooking = v;
              }),
              menu('Cleaning', cleaning, profileCleaningOptions, (v) {
                cleaning = v;
              }),
              menu('Pets', pets, profilePetOptions, (v) => pets = v),
            ],
          );
        },
      ),
    );
    if (saved == true) {
      await _commit(
        _draft.copyWith(
          smoking: smoking,
          drinking: drinking,
          food: food,
          cooking: cooking,
          cleaning: cleaning,
          pets: pets,
        ),
      );
    }
  }

  Future<void> _editLanguages() async {
    final selected = {..._draft.languages};
    final saved = await _openSection(
      title: 'Language Known',
      child: StatefulBuilder(
        builder: (context, setLocal) {
          return KitMultiChoice(
            label: 'Languages you know',
            icon: RealLifeIcons.language,
            selected: selected,
            options: [
              for (final language in profileWizardLanguages)
                KitOption(
                  value: language,
                  label: language,
                  icon: RealLifeIcons.language,
                  key: Key('profile-edit-language-$language'),
                ),
            ],
            onChanged: (next) => setLocal(() {
              selected
                ..clear()
                ..addAll(next);
            }),
          );
        },
      ),
    );
    if (saved == true) {
      await _commit(_draft.copyWith(languages: selected.toList()));
    }
  }

  Future<void> _editRequirements() async {
    final min = TextEditingController(text: _draft.budgetMin?.toString() ?? '');
    final max = TextEditingController(text: _draft.budgetMax?.toString() ?? '');
    final places = TextEditingController();
    final chosen = [..._draft.localities];
    final move = TextEditingController(text: _draft.moveInLabel);
    final looking = {..._draft.lookingFor};
    final saved = await _openSection(
      title: 'My Requirements',
      child: StatefulBuilder(
        builder: (context, setLocal) {
          return Column(
            children: [
              KitTextField(
                fieldKey: const Key('profile-edit-budget-min'),
                label: 'Budget min',
                controller: min,
                hint: '15000',
                icon: RealLifeIcons.wallet,
                keyboardType: TextInputType.number,
              ),
              KitTextField(
                label: 'Budget max',
                controller: max,
                hint: '35000',
                icon: RealLifeIcons.wallet,
                keyboardType: TextInputType.number,
              ),
              if (chosen.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final name in chosen)
                      InputChip(
                        label: Text(name),
                        onDeleted: () => setLocal(() => chosen.remove(name)),
                      ),
                  ],
                ),
              PlaceAutocompleteField(
                fieldKey: const Key('profile-edit-localities'),
                controller: places,
                labelText: 'Add locality',
                hintText: 'Search a locality',
                prefixIcon: const Icon(
                  RealLifeIcons.pin,
                  color: HomiziColors.logoOrange,
                ),
                stackedLabel: true,
                pickOnly: true,
                commitLabel: false,
                includedPrimaryTypes: const ['sublocality', 'neighborhood'],
                textCapitalization: TextCapitalization.words,
                onSelected: (place) {
                  final name = (place.locality ?? place.label.split(',').first)
                      .trim();
                  places.clear();
                  if (name.isEmpty || chosen.contains(name)) {
                    return;
                  }
                  setLocal(() => chosen.add(name));
                  if (place.hasCoordinates) {
                    unawaited(
                      writeDeviceString(
                        'flutter.homizi.profile_place',
                        jsonEncode({
                          'label': place.label,
                          'latitude': place.latitude,
                          'longitude': place.longitude,
                        }),
                      ),
                    );
                  }
                },
              ),
              HomiziDateField(
                fieldKey: const Key('profile-edit-move-in'),
                controller: move,
                label: 'Move-in',
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
              ),
              KitMultiChoice(
                label: 'Looking for',
                icon: RealLifeIcons.house,
                selected: looking,
                options: [
                  for (final type in ['private_room', 'shared_room'])
                    KitOption(
                      value: type,
                      label: tenantPropertyTypeLabel(type),
                      icon: type == 'shared_room'
                          ? RealLifeIcons.sharedRoom
                          : RealLifeIcons.privateRoom,
                    ),
                ],
                onChanged: (next) => setLocal(() {
                  looking
                    ..clear()
                    ..addAll(next);
                }),
              ),
            ],
          );
        },
      ),
    );
    if (saved == true) {
      await _commit(
        _draft.copyWith(
          budgetMin: int.tryParse(min.text.trim()),
          budgetMax: int.tryParse(max.text.trim()),
          localities: [...chosen],
          moveInLabel: move.text.trim(),
          lookingFor: looking.toList(),
        ),
      );
    }
  }

  Future<void> _addDocument() async {
    final name = TextEditingController();
    final saved = await _openSection(
      title: 'Add Document',
      child: KitTextField(
        fieldKey: const Key('profile-document-name'),
        label: 'Document name',
        controller: name,
        hint: 'PAN Card',
        icon: RealLifeIcons.document,
        textCapitalization: TextCapitalization.words,
      ),
    );
    final label = name.text.trim();
    if (saved == true && label.isNotEmpty) {
      await _commit(_draft.copyWith(documents: [..._draft.documents, label]));
    }
  }

  Widget _section({
    required String title,
    required String editKey,
    required VoidCallback onEdit,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    homiziText(context, title),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  key: Key(editKey),
                  tooltip: homiziText(context, 'Edit'),
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: child);
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              homiziText(context, label),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: HomiziColors.muted),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ListingGrid extends StatelessWidget {
  const _ListingGrid({required this.listings, required this.coverFor});

  final List<OwnerListing> listings;
  final String? Function(OwnerListing listing) coverFor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 2.0;
        final tile = (constraints.maxWidth - gap * 2) / 3;
        return Wrap(
          key: const Key('profile-listings-grid'),
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final listing in listings)
              Semantics(
                label: listing.title,
                child: SizedBox(
                  key: Key('profile-listing-${listing.id}'),
                  width: tile,
                  height: tile,
                  child: coverFor(listing) == null
                      ? const ColoredBox(
                          color: HomiziColors.soft,
                          child: Icon(
                            Icons.apartment_outlined,
                            color: HomiziColors.ink,
                          ),
                        )
                      : ListingPhoto(asset: coverFor(listing)),
                ),
              ),
          ],
        );
      },
    );
  }
}
