import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/locale_controller.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/auth/otp/contact_badges.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/profile/avatar_actions.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/domain/profile_completion.dart';
import 'package:homizi/features/profile/domain/profile_contact.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/public_profile.dart';
import 'package:homizi/features/publish/published_activity.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_providers.dart';
import 'package:homizi/l10n/app_localizations.dart';

class ProfileHubScreen extends ConsumerStatefulWidget {
  const ProfileHubScreen({super.key});

  @override
  ConsumerState<ProfileHubScreen> createState() => _ProfileHubScreenState();
}

class _ProfileHubScreenState extends ConsumerState<ProfileHubScreen> {
  TenantProfile _profile = const TenantProfile();
  ProfileActivity _activity = ProfileActivity.empty;
  var _loading = true;
  String? _error;
  String? _note;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await ref
          .read(accountGatewayProvider)
          .loadTenantProfile();
      final activity = await ref.read(profileHubGatewayProvider).loadActivity();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _activity = activity;
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
    } on ProfileHubFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _role(AccountRole role) async {
    final message = await ref.read(sessionProvider.notifier).selectRole(role);
    if (!mounted) {
      return;
    }
    setState(() {
      _note = message;
    });
  }

  void _open(String path, {bool go = false}) {
    if (go) {
      context.go(path);
      return;
    }
    context.push(path);
  }

  Future<void> _openKyc() async {
    await context.push(RoutePaths.verifyIdentity);
    if (mounted) {
      ref.invalidate(myKycProvider);
    }
  }

  void _share() {
    openDemoSuccess(
      context,
      title: 'Profile link ready',
      detail: 'Your phone number stays hidden.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(localeProvider);
    final copy = AppLocalizations.of(context);
    final config = ref.watch(appConfigProvider);
    final offlineDemo =
        !config.connectsToSupabase ||
        ref.watch(forceDemoModeProvider) ||
        config.demoSkipLogin;
    final verification = ref.watch(ownVerificationProvider);
    final kyc =
        ref.watch(myKycProvider).asData?.value ?? KycSnapshot.notStarted;
    final facts = profileHeaderFacts(
      profile: _profile,
      sessionContact: session.contact,
      nickname: verification.nickname,
      offlineDemo: offlineDemo,
    );
    final score = profileCompletion(
      CompletionInput(
        displayName: facts.displayName == 'Your profile'
            ? ''
            : facts.displayName,
        occupation: facts.occupation,
        bio: facts.bio,
        hasBudget:
            facts.preferences.budgetMinInr != null ||
            facts.preferences.budgetMaxInr != null,
        hasLocality: facts.preferences.localities.isNotEmpty,
        hasRole: session.role != null,
      ),
    );
    final role = session.role;
    final homiziRole = ref.watch(currentRoleProvider);
    final portraitName =
        facts.usingShowcase || _profile.displayName.trim().isNotEmpty
        ? facts.displayName
        : '';
    final shownToOthers = verification.copyWith(
      viewerVerified: verification.isVerified,
      nickname: verification.nickname.trim().isEmpty
          ? (facts.usingShowcase
                ? facts.displayName
                : _profile.displayName.trim())
          : verification.nickname,
      photoRef: verification.photoRef ?? _profile.avatarUrl,
    );
    final visitsPath = homiziRole == HomiziRole.tenant
        ? RoutePaths.tenantVisits
        : RoutePaths.hostVisits;
    final roleLabel = _accountRoleLabel(role, homiziRole);
    final idVerification = _idVerificationValue(
      verification,
      _profile.verification,
    );
    final subtitle = facts.occupation.trim().isEmpty
        ? 'Add what you do'
        : facts.occupation.trim();

    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Material(
                      color: HomiziColors.accent,
                      child: Column(
                        children: [
                          SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(4, 4, 20, 8),
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 48,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        const Align(
                                          alignment: Alignment.centerLeft,
                                          child: HomiziBackButton(),
                                        ),
                                        Text(
                                          homiziText(context, 'Profile'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: HomiziColors.ink,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ProfilePhotoRow(
                                    name: portraitName,
                                    photoRef: _profile.avatarUrl,
                                    gateway: ref.read(accountGatewayProvider),
                                    centered: true,
                                    onSaved: (next) => setState(() {
                                      _profile = next == null
                                          ? _profile.copyWith(clearAvatar: true)
                                          : _profile.copyWith(avatarUrl: next);
                                    }),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    homiziText(context, facts.displayName),
                                    key: const Key('profile-name'),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(color: HomiziColors.ink),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    key: const Key('profile-initials'),
                                    homiziText(context, subtitle),
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: HomiziColors.ink,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  if (homiziRole == HomiziRole.broker) ...[
                                    const SizedBox(height: 8),
                                    const BrokerChip(),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _QuickAction(
                                        actionKey: const Key(
                                          'profile-action-saved',
                                        ),
                                        icon: Icons.favorite_border,
                                        label: 'Saved',
                                        onTap: () =>
                                            _open(RoutePaths.saved, go: true),
                                      ),
                                      _QuickAction(
                                        actionKey: const Key(
                                          'profile-action-visits',
                                        ),
                                        icon: Icons.event_outlined,
                                        label: 'Visits',
                                        onTap: () => _open(visitsPath),
                                      ),
                                      _QuickAction(
                                        actionKey: const Key(
                                          'profile-action-settings',
                                        ),
                                        icon: Icons.settings_outlined,
                                        label: 'Settings',
                                        onTap: () => _open(RoutePaths.settings),
                                      ),
                                      _QuickAction(
                                        actionKey: const Key(
                                          'profile-action-verify',
                                        ),
                                        icon: Icons.verified_outlined,
                                        label: kyc.isVerified
                                            ? 'Verified'
                                            : 'Get verified',
                                        onTap: () => _openKyc(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),
                          Material(
                            color: HomiziColors.white,
                            clipBehavior: Clip.antiAlias,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(28),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                12,
                                20,
                                28,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_loading)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: Text(
                                        homiziText(context, 'Loading…'),
                                      ),
                                    ),
                                  if (_error != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: LiveNotice(
                                        key: const Key('profile-error'),
                                        message: homiziText(context, _error!),
                                        isError: true,
                                      ),
                                    ),
                                  if (_note != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: LiveNotice(
                                        key: const Key('profile-note'),
                                        message: homiziText(context, _note!),
                                      ),
                                    ),
                                  ContactVerifyBadges(
                                    email: facts.email,
                                    phone: profilePhoneDisplay(
                                      phoneE164: session.phoneE164,
                                      fallback: facts.phone,
                                    ),
                                    emailVerified: session.emailVerified,
                                    phoneVerified: session.phoneVerified,
                                    onVerifyEmail: session.emailVerified
                                        ? null
                                        : () => _open(
                                            '${RoutePaths.verifyContact}?channel=email',
                                          ),
                                    onVerifyPhone: session.phoneVerified
                                        ? null
                                        : () => _open(
                                            '${RoutePaths.verifyContact}?channel=phone',
                                          ),
                                  ),
                                  _DetailRow(
                                    icon: Icons.alternate_email,
                                    label: 'Handle',
                                    value: facts.handle,
                                    valueKey: const Key('profile-handle'),
                                  ),
                                  _DetailRow(
                                    rowKey: const Key('profile-change-role'),
                                    icon: Icons.badge_outlined,
                                    label: 'Role',
                                    value: roleLabel,
                                    onTap: () => _open(RoutePaths.personalize),
                                  ),
                                  if (role != null) ...[
                                    const SizedBox(height: 8),
                                    SegmentedButton<AccountRole>(
                                      key: const Key('profile-role'),
                                      segments: [
                                        ButtonSegment(
                                          value: AccountRole.tenant,
                                          label: Text(
                                            homiziText(context, 'Tenant'),
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: AccountRole.host,
                                          label: Text(
                                            homiziText(
                                              context,
                                              homiziRole == HomiziRole.broker
                                                  ? 'Broker'
                                                  : 'Host',
                                            ),
                                          ),
                                        ),
                                        ButtonSegment(
                                          value: AccountRole.both,
                                          label: Text(
                                            homiziText(context, 'Both'),
                                          ),
                                        ),
                                      ],
                                      selected: {role},
                                      onSelectionChanged: (next) =>
                                          unawaited(_role(next.first)),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  _DetailRow(
                                    rowKey: const Key(
                                      'profile-edit-requirements',
                                    ),
                                    icon: Icons.home_outlined,
                                    label: 'What you need',
                                    value: preferenceLine(facts.preferences),
                                    onTap: () => _open(RoutePaths.requirement),
                                  ),
                                  _DetailRow(
                                    rowKey: const Key('profile-verification'),
                                    icon: Icons.verified_outlined,
                                    label: 'ID verification (Aadhaar & selfie)',
                                    value: idVerification,
                                    valueKey: idVerification == 'Verified'
                                        ? const Key('profile-verified-status')
                                        : null,
                                    valueColor: idVerification == 'Verified'
                                        ? HomiziColors.success
                                        : null,
                                    onTap: () =>
                                        _open(RoutePaths.verifyIdentity),
                                  ),
                                  _DetailRow(
                                    rowKey: const Key('profile-kyc'),
                                    icon: kyc.isVerified
                                        ? Icons.verified
                                        : Icons.verified_user_outlined,
                                    label: 'Aadhaar & face',
                                    value: kyc.isVerified
                                        ? 'Verified'
                                        : 'Get verified',
                                    valueKey: const Key('profile-kyc-value'),
                                    valueColor: kyc.isVerified
                                        ? HomiziColors.success
                                        : HomiziColors.logoOrange,
                                    onTap: () => _openKyc(),
                                  ),
                                  if (verification.badges.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    ProfileVerificationBadges(
                                      badges: verification.badges,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  SwitchListTile(
                                    key: const Key('profile-photo-privacy'),
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      homiziText(
                                        context,
                                        'Show my photo to verified users',
                                      ),
                                    ),
                                    subtitle: Text(
                                      homiziText(
                                        context,
                                        'Off by default. Your photo stays private until you turn this on.',
                                      ),
                                    ),
                                    value:
                                        verification.showPhotoToVerifiedUsers,
                                    onChanged: (value) {
                                      ref
                                          .read(
                                            ownVerificationProvider.notifier,
                                          )
                                          .replace(
                                            verification.copyWith(
                                              showPhotoToVerifiedUsers: value,
                                            ),
                                          );
                                    },
                                  ),
                                  const _SectionGap(),
                                  Text(
                                    homiziText(context, 'What others see'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  PublicProfileCard(profile: shownToOthers),
                                  const SizedBox(height: 16),
                                  Text(
                                    homiziText(
                                      context,
                                      'Profile ${score.filled} of ${score.total}',
                                    ),
                                    key: const Key('profile-completion'),
                                  ),
                                  const SizedBox(height: 8),
                                  Semantics(
                                    label: homiziText(
                                      context,
                                      'Profile ${score.filled} of ${score.total}',
                                    ),
                                    value:
                                        '${(score.fraction * 100).round()} percent complete',
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: LinearProgressIndicator(
                                        minHeight: 8,
                                        value: score.fraction,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    homiziText(
                                      context,
                                      'Name, work, a short bio, a budget, a locality, and a role.',
                                    ),
                                  ),
                                  const _SectionGap(),
                                  Text(
                                    homiziText(
                                      context,
                                      copy?.languageTitle ?? 'Language',
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  SegmentedButton<String>(
                                    key: const Key('profile-language'),
                                    segments: [
                                      ButtonSegment(
                                        value: 'en',
                                        label: Text(
                                          homiziText(
                                            context,
                                            copy?.languageEnglish ?? 'English',
                                          ),
                                        ),
                                      ),
                                      ButtonSegment(
                                        value: 'hi',
                                        label: Text(
                                          homiziText(
                                            context,
                                            copy?.languageHindi ?? 'Hindi',
                                          ),
                                        ),
                                      ),
                                    ],
                                    selected: {locale.languageCode},
                                    onSelectionChanged: (next) {
                                      ref
                                          .read(localeProvider.notifier)
                                          .setCode(next.first);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _DetailRow(
                                    rowKey: const Key('profile-open-settings'),
                                    icon: Icons.settings_outlined,
                                    label: 'Settings',
                                    value:
                                        'Account, verification, notifications, privacy, payments, and help.',
                                    onTap: () => _open(RoutePaths.settings),
                                  ),
                                  _DetailRow(
                                    icon: Icons.person_outline,
                                    label: 'Tenant profile',
                                    value: 'Name, work, and a short bio.',
                                    onTap: () =>
                                        _open(RoutePaths.tenantProfile),
                                  ),
                                  _DetailRow(
                                    icon: Icons.home_work_outlined,
                                    label: 'Host profile',
                                    value: 'How you list a home.',
                                    onTap: () => _open(RoutePaths.hostProfile),
                                  ),
                                  _DetailRow(
                                    rowKey: const Key('profile-rent-split'),
                                    icon: Icons.calculate_outlined,
                                    label: 'Rent split calculator',
                                    value: 'Split rent fairly with roommates.',
                                    onTap: () => _open(RoutePaths.rentSplit),
                                  ),
                                  _DetailRow(
                                    rowKey: const Key('profile-shared-home'),
                                    icon: Icons.bedroom_parent_outlined,
                                    label: 'Rooms in shared homes',
                                    value:
                                        'Find a home by actual free rooms, alone or as a group.',
                                    onTap: () => _open(SharedHomePaths.search),
                                  ),
                                  _DetailRow(
                                    rowKey: const Key(
                                      'profile-post-shared-home',
                                    ),
                                    icon: Icons.add_home_outlined,
                                    label: 'Post a shared home',
                                    value:
                                        'Add who lives there and which rooms are free.',
                                    onTap: () => _open(SharedHomePaths.host),
                                  ),
                                  if (homiziRole == HomiziRole.host ||
                                      homiziRole == HomiziRole.broker)
                                    _DetailRow(
                                      rowKey: const Key('profile-host-options'),
                                      icon: Icons.handyman_outlined,
                                      label: homiziRole == HomiziRole.broker
                                          ? 'Broker tools'
                                          : 'Host options',
                                      value: homiziRole == HomiziRole.broker
                                          ? 'Registration and leads.'
                                          : 'How you want to start.',
                                      onTap: () => _open(
                                        homiziRole == HomiziRole.broker
                                            ? RoutePaths.brokerRegister
                                            : RoutePaths.hostOptions,
                                      ),
                                    ),
                                  const _SectionGap(),
                                  Text(
                                    homiziText(context, 'My activity'),
                                    key: const Key('profile-activity'),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  const PublishedActivitySection(),
                                  _ActivityRow(
                                    title: 'Saved',
                                    icon: Icons.favorite_border,
                                    count: _activity.savedCount,
                                    onTap: () =>
                                        _open(RoutePaths.saved, go: true),
                                  ),
                                  _ActivityRow(
                                    title: 'Recently viewed',
                                    icon: Icons.history,
                                    count: _activity.viewedAvailable
                                        ? _activity.viewedCount
                                        : null,
                                    onTap: () =>
                                        _open(RoutePaths.recentlyViewed),
                                  ),
                                  _ActivityRow(
                                    title: 'Requests',
                                    icon: Icons.assignment_outlined,
                                    count: _activity.requestCount,
                                    onTap: () => _open(RoutePaths.requirement),
                                  ),
                                  _ActivityRow(
                                    title: 'Visits',
                                    icon: Icons.event_outlined,
                                    count: _activity.visitCount,
                                    buttonKey: const Key(
                                      'activity-open-visits',
                                    ),
                                    onTap: () => _open(visitsPath),
                                  ),
                                  _ActivityRow(
                                    title: 'Matches',
                                    icon: Icons.handshake_outlined,
                                    count: _activity.matchCount,
                                    onTap: () =>
                                        _open(RoutePaths.matches, go: true),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: const BoxDecoration(
                color: HomiziColors.white,
                boxShadow: [
                  BoxShadow(
                    color: HomiziColors.shadowSoft,
                    blurRadius: 12,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          key: const Key('profile-primary-action'),
                          onPressed: () => _open(RoutePaths.requirement),
                          child: Text(
                            homiziText(context, 'Edit what you need'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        key: const Key('profile-share'),
                        tooltip: homiziText(context, 'Share'),
                        onPressed: _share,
                        style: IconButton.styleFrom(
                          backgroundColor: HomiziColors.white,
                          foregroundColor: HomiziColors.ink,
                          side: const BorderSide(
                            color: HomiziColors.accent,
                            width: 1.5,
                          ),
                          minimumSize: const Size(48, 48),
                          fixedSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.share_outlined),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _accountRoleLabel(AccountRole? role, HomiziRole? homiziRole) {
  return switch (role) {
    AccountRole.tenant => 'Tenant',
    AccountRole.host => homiziRole == HomiziRole.broker ? 'Broker' : 'Host',
    AccountRole.both => 'Both',
    null => 'Choose how you use HOMIZI',
  };
}

/// Identity check only. Email and mobile have their own rows.
String _idVerificationValue(
  PublicProfile verification,
  VerificationStatus status,
) {
  final idDone = verification.identityVerified && verification.selfieVerified;
  if (idDone || status == VerificationStatus.mockVerified) {
    return 'Verified';
  }
  if (status == VerificationStatus.rejected) {
    return 'Rejected';
  }
  if (status == VerificationStatus.mockPending ||
      verification.identityVerified ||
      verification.selfieVerified) {
    return 'Pending';
  }
  return 'Not started';
}

class _SectionGap extends StatelessWidget {
  const _SectionGap();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: ColoredBox(
        color: HomiziColors.soft,
        child: SizedBox(height: 8, width: double.infinity),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HomiziColors.soft,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: HomiziColors.accent, size: 20),
      ),
    );
  }
}

class _RoundArrow extends StatelessWidget {
  const _RoundArrow();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Icon(Icons.arrow_forward, size: 16, color: HomiziColors.ink),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: homiziText(context, label),
      child: InkWell(
        key: actionKey,
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 76,
          child: Column(
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: HomiziColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: HomiziColors.shadowSoft,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(icon, color: HomiziColors.ink),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                homiziText(context, label),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.rowKey,
    this.valueKey,
    this.valueColor,
    this.onTap,
  });

  final Key? rowKey;
  final Key? valueKey;
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: rowKey,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _IconBadge(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, label),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      homiziText(context, value),
                      key: valueKey,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: valueColor ?? HomiziColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const _RoundArrow(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.title,
    required this.icon,
    required this.count,
    required this.onTap,
    this.buttonKey,
  });

  final String title;
  final IconData icon;
  final int? count;
  final VoidCallback onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    final slug = title.toLowerCase().replaceAll(' ', '-');
    return InkWell(
      key: buttonKey,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              _IconBadge(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  homiziText(context, title),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                count == null ? '—' : '$count',
                key: Key('activity-$slug'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(width: 8),
              const _RoundArrow(),
            ],
          ),
        ),
      ),
    );
  }
}
