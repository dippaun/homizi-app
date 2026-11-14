import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/domain/profile_completion.dart';
import 'package:homizi/features/profile/profile_dashboard_model.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_create_widgets.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_providers.dart';

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
  var _loading = true;
  String? _error;
  var _tab = 0;
  var _switching = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _draft = ref.read(profileCreateStoreProvider).draft;
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
    if (mounted) {
      setState(() => _loading = false);
    }
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

  bool get _aadhaarVerified => _kyc.aadhaarVerified || _draft.aadhaarVerified;

  @override
  Widget build(BuildContext context) {
    final wire =
        ref.watch(currentRoleProvider)?.name ?? profilePrimaryWire(_draft);
    final host = profileHostSide(wire);
    final stats = profileDashboardStats(_activity);
    final score = profileWizardCompleteness(
      draft: _draft,
      profile: _profile,
      aadhaarVerified: _aadhaarVerified,
    );
    final name = _displayName();
    final media = ref.watch(profileMediaProvider);
    return RepaintBoundary(
      key: const Key('profile-me-shot'),
      child: Scaffold(
        key: const Key('profile-me-screen'),
        backgroundColor: HomiziColors.soft,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: HomiziColors.white,
          surfaceTintColor: HomiziColors.white,
          leading: const HomiziBackButton(),
          title: Text(
            homiziText(context, 'HOMIZI'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: HomiziColors.logoOrange,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          actions: [
            IconButton(
              key: const Key('profile-me-bell'),
              tooltip: homiziText(context, 'Notifications'),
              onPressed: () => context.push(RoutePaths.notifications),
              icon: const Icon(Icons.notifications_none),
            ),
            IconButton(
              key: const Key('profile-me-settings'),
              tooltip: homiziText(context, 'Settings'),
              onPressed: () => context.push(RoutePaths.settings),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: LinearProgressIndicator(
                    key: Key('profile-me-loading'),
                    color: HomiziColors.logoOrange,
                  ),
                ),
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
              _header(name, wire, host, media.photo),
              const SizedBox(height: 12),
              _stats(stats),
              const SizedBox(height: 12),
              _completeness(score),
              const SizedBox(height: 12),
              _tabs(),
              const SizedBox(height: 12),
              switch (_tab) {
                1 => _preferences(host),
                2 => _listingsPane(host),
                3 => _activityPane(),
                4 => _verification(),
                _ => _myProfile(host),
              },
            ],
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

  Widget _header(String name, String? wire, bool host, Uint8List? photo) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [HomiziColors.brandGolden, HomiziColors.logoOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: HomiziColors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipOval(
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: _portrait(photo, name),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  key: const Key('profile-name'),
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              if (_aadhaarVerified) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.verified,
                                  key: Key('profile-me-verified'),
                                  color: HomiziColors.success,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          Chip(
                            label: Text(
                              homiziText(context, profileRoleChip(wire)),
                              key: const Key('profile-me-role'),
                            ),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: HomiziColors.accentWash,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('profile-role-switch'),
                    onPressed: _switching
                        ? null
                        : () => unawaited(_switchRole()),
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(
                      homiziText(
                        context,
                        _switching
                            ? 'Switching…'
                            : 'Switch your role (Tenant ↔ Host)',
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const Key('profile-change-role'),
                    onPressed: () => context.push(RoutePaths.personalize),
                    child: Text(homiziText(context, 'Change role')),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    key: const Key('profile-edit-basic'),
                    onPressed: () => unawaited(_editBasic()),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: Text(homiziText(context, 'Edit Profile')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _portrait(Uint8List? photo, String name) {
    if (photo != null) {
      return Image.memory(photo, fit: BoxFit.cover);
    }
    final ref = _draft.showPhotoToVerifiedUsers
        ? _draft.sampleAvatar
        : _profile.avatarUrl;
    final path = (ref ?? _profile.avatarUrl)?.trim() ?? '';
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    if (path.startsWith('data:')) {
      final comma = path.indexOf(',');
      if (comma > 0) {
        try {
          return Image.memory(
            base64Decode(path.substring(comma + 1)),
            fit: BoxFit.cover,
          );
        } on Object {
          // Fall through to initials.
        }
      }
    }
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover);
    }
    return ColoredBox(
      color: HomiziColors.accentWash,
      child: Center(
        child: Text(
          profileInitials(name),
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }

  Widget _stats(ProfileDashboardStats stats) {
    return _panel(
      child: Row(
        children: [
          _stat('Matches', stats.matches, 'profile-stat-matches'),
          _stat('Saved', stats.saved, 'profile-stat-saved'),
          _stat('Views', stats.views, 'profile-stat-views'),
          _stat('Inquiries', stats.inquiries, 'profile-stat-inquiries'),
        ],
      ),
    );
  }

  Widget _stat(String label, int value, String key) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            key: Key(key),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(homiziText(context, label)),
        ],
      ),
    );
  }

  Widget _completeness(ProfileCompleteness score) {
    return _panel(
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score.percent / 100,
                  color: HomiziColors.logoOrange,
                  backgroundColor: HomiziColors.line,
                ),
                Text(
                  '${score.percent}%',
                  key: const Key('profile-completeness'),
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, 'Profile Completeness'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(homiziText(context, score.line)),
              ],
            ),
          ),
          TextButton(
            key: const Key('profile-complete-now'),
            onPressed: () => context.push(RoutePaths.profileCreate),
            child: Text(homiziText(context, 'Complete Now')),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    const labels = [
      'My Profile',
      'Preferences',
      'My Listings',
      'Activity',
      'Verification',
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('profile-tab-${labels[i]}'),
                label: Text(homiziText(context, labels[i])),
                selected: _tab == i,
                onSelected: (_) => setState(() => _tab = i),
              ),
            ),
        ],
      ),
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
    return Column(
      children: [
        _prioritiesEntry(),
        _lifestyleCard(),
        _section(
          title: 'Languages',
          editKey: 'profile-edit-languages',
          onEdit: () => unawaited(_editLanguages()),
          child: _draft.languages.isEmpty
              ? Text(homiziText(context, 'Add the languages you know.'))
              : Wrap(
                  spacing: 8,
                  children: [
                    for (final language in _draft.languages)
                      Chip(label: Text(homiziText(context, language))),
                  ],
                ),
        ),
        if (!host) _requirements(),
      ],
    );
  }

  Widget _listingsPane(bool host) {
    if (!host) {
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
              homiziText(
                context,
                'Switch to Host to manage homes, or add a listing on this account.',
              ),
            ),
            TextButton(
              key: const Key('profile-add-listing'),
              onPressed: () => context.push(RoutePaths.listingEditor),
              child: Text(homiziText(context, 'Add a listing')),
            ),
          ],
        ),
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
            TextButton(
              key: const Key('profile-add-listing'),
              onPressed: () => context.push(RoutePaths.listingEditor),
              child: Text(homiziText(context, 'Add a listing')),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('profile-add-listing'),
            onPressed: () => context.push(RoutePaths.listingEditor),
            child: Text(homiziText(context, 'Add a listing')),
          ),
        ),
        for (final listing in _listings)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _panel(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(listing.title),
                subtitle: Text(
                  '${listing.place} · ₹ ${listing.rentInr} · ${listing.views} views · ${listing.interests} inquiries',
                ),
                trailing: Text(homiziText(context, listing.chip)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _activityPane() {
    if (_activity.matchCount == 0 &&
        _activity.savedCount == 0 &&
        _activity.viewedCount == 0 &&
        _activity.requestCount == 0) {
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
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, 'Verification Status'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _check('Mobile', _draft.mobileVerified),
          _check('Email', _draft.emailVerified),
          _check('Aadhaar', _aadhaarVerified),
          if (!_aadhaarVerified)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                homiziText(
                  context,
                  _kyc.unavailable
                      ? kycComingSoonCopy
                      : aadhaarStatusLabel(_kyc.aadhaarStatus),
                ),
                key: const Key('profile-aadhaar-state'),
              ),
            ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.push(RoutePaths.verifyIdentity),
            child: Text(homiziText(context, 'Get verified')),
          ),
        ],
      ),
    );
  }

  Widget _check(String label, bool ok) {
    return ProfileCheckLine(
      label: ok ? '$label Verified' : '$label not verified',
      color: ok ? profileVerifiedGreen : HomiziColors.muted,
      iconKey: Key('profile-verify-$label'),
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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: HomiziColors.line),
        ),
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

  Future<void> _editBasic() async {
    final nick = TextEditingController(text: _draft.nickname);
    final surname = TextEditingController(text: _draft.surname);
    final company = TextEditingController(text: _draft.companyName);
    final city = TextEditingController(text: _draft.city);
    final full = TextEditingController(
      text: [
        _draft.firstName,
        _draft.lastName,
      ].where((part) => part.trim().isNotEmpty).join(' '),
    );
    var occupation = _draft.occupation;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(homiziText(context, 'Basic Information')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: full,
                  decoration: const InputDecoration(
                    labelText: 'Full Name (private)',
                  ),
                ),
                TextField(
                  key: const Key('profile-edit-nick'),
                  controller: nick,
                  decoration: const InputDecoration(labelText: 'Nick Name'),
                ),
                TextField(
                  controller: surname,
                  decoration: const InputDecoration(labelText: 'Surname'),
                ),
                TextField(
                  controller: company,
                  decoration: const InputDecoration(labelText: 'Company'),
                ),
                TextField(
                  key: const Key('profile-edit-city'),
                  controller: city,
                  decoration: const InputDecoration(labelText: 'Current City'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: occupation,
                  decoration: const InputDecoration(labelText: 'Occupation'),
                  items: [
                    for (final option in profileOccupationOptions)
                      DropdownMenuItem(value: option, child: Text(option)),
                  ],
                  onChanged: (value) => occupation = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(homiziText(context, 'Cancel')),
            ),
            TextButton(
              key: const Key('profile-edit-save'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(homiziText(context, 'Save')),
            ),
          ],
        );
      },
    );
    if (saved != true) {
      return;
    }
    final legal = splitProfileLegalName(full.text);
    await _save(
      _draft.copyWith(
        firstName: legal.$1.isEmpty ? _draft.firstName : legal.$1,
        lastName: legal.$2.isEmpty ? _draft.lastName : legal.$2,
        nickname: nick.text.trim(),
        surname: surname.text.trim(),
        companyName: company.text.trim(),
        city: city.text.trim(),
        occupation: occupation,
      ),
    );
  }

  Future<void> _editAbout() async {
    final about = TextEditingController(text: _draft.about);
    final tags = TextEditingController(text: _draft.tags.join(', '));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(homiziText(context, 'About Me')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('profile-edit-about-field'),
                controller: about,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'About Me'),
              ),
              TextField(
                controller: tags,
                decoration: const InputDecoration(
                  labelText: 'Tags, separated by commas',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(homiziText(context, 'Cancel')),
            ),
            TextButton(
              key: const Key('profile-edit-save'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(homiziText(context, 'Save')),
            ),
          ],
        );
      },
    );
    if (saved == true) {
      await _save(
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Widget menu(
              String label,
              String? value,
              List<String> options,
              ValueChanged<String?> onChanged,
            ) {
              return DropdownButtonFormField<String>(
                initialValue: value,
                decoration: InputDecoration(labelText: label),
                items: [
                  for (final option in options)
                    DropdownMenuItem(value: option, child: Text(option)),
                ],
                onChanged: (next) => setLocal(() => onChanged(next)),
              );
            }

            return AlertDialog(
              title: Text(homiziText(context, 'Lifestyle & Preferences')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(homiziText(context, 'Cancel')),
                ),
                TextButton(
                  key: const Key('profile-edit-save'),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(homiziText(context, 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      await _save(
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
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(homiziText(context, 'Language Known')),
              content: Wrap(
                spacing: 8,
                children: [
                  for (final language in profileWizardLanguages)
                    FilterChip(
                      label: Text(language),
                      selected: selected.contains(language),
                      onSelected: (on) => setLocal(() {
                        if (on) {
                          selected.add(language);
                        } else {
                          selected.remove(language);
                        }
                      }),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(homiziText(context, 'Cancel')),
                ),
                TextButton(
                  key: const Key('profile-edit-save'),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(homiziText(context, 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      await _save(_draft.copyWith(languages: selected.toList()));
    }
  }

  Future<void> _editRequirements() async {
    final min = TextEditingController(text: _draft.budgetMin?.toString() ?? '');
    final max = TextEditingController(text: _draft.budgetMax?.toString() ?? '');
    final places = TextEditingController(text: _draft.localities.join(', '));
    final move = TextEditingController(text: _draft.moveInLabel);
    final looking = {..._draft.lookingFor};
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(homiziText(context, 'My Requirements')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      key: const Key('profile-edit-budget-min'),
                      controller: min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budget min',
                      ),
                    ),
                    TextField(
                      controller: max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Budget max',
                      ),
                    ),
                    TextField(
                      controller: places,
                      decoration: const InputDecoration(
                        labelText: 'Localities, separated by commas',
                      ),
                    ),
                    TextField(
                      controller: move,
                      decoration: const InputDecoration(labelText: 'Move-in'),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final type in ['private_room', 'shared_room'])
                          FilterChip(
                            label: Text(tenantPropertyTypeLabel(type)),
                            selected: looking.contains(type),
                            onSelected: (on) => setLocal(() {
                              if (on) {
                                looking.add(type);
                              } else {
                                looking.remove(type);
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(homiziText(context, 'Cancel')),
                ),
                TextButton(
                  key: const Key('profile-edit-save'),
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(homiziText(context, 'Save')),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved == true) {
      await _save(
        _draft.copyWith(
          budgetMin: int.tryParse(min.text.trim()),
          budgetMax: int.tryParse(max.text.trim()),
          localities: [
            for (final place in places.text.split(','))
              if (place.trim().isNotEmpty) place.trim(),
          ],
          moveInLabel: move.text.trim(),
          lookingFor: looking.toList(),
        ),
      );
    }
  }

  Future<void> _addDocument() async {
    final name = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(homiziText(context, 'Add Document')),
          content: TextField(
            key: const Key('profile-document-name'),
            controller: name,
            decoration: const InputDecoration(labelText: 'Document name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(homiziText(context, 'Cancel')),
            ),
            TextButton(
              key: const Key('profile-edit-save'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(homiziText(context, 'Save')),
            ),
          ],
        );
      },
    );
    final label = name.text.trim();
    if (saved == true && label.isNotEmpty) {
      await _save(_draft.copyWith(documents: [..._draft.documents, label]));
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        border: Border.all(color: HomiziColors.line),
      ),
      child: child,
    );
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
