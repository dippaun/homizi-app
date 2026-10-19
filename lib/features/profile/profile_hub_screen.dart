import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/locale_controller.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/profile/avatar_actions.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/domain/profile_completion.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(localeProvider);
    final copy = AppLocalizations.of(context);
    final name = _profile.displayName.trim();
    final score = profileCompletion(
      CompletionInput(
        displayName: _profile.displayName,
        occupation: _profile.occupation,
        bio: _profile.bio,
        hasBudget:
            _profile.preferences.budgetMinInr != null ||
            _profile.preferences.budgetMaxInr != null,
        hasLocality: _profile.preferences.localities.isNotEmpty,
        hasRole: session.role != null,
      ),
    );
    final role = session.role;
    final homiziRole = ref.watch(currentRoleProvider);
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Profile'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfilePhotoRow(
                      name: name,
                      photoRef: _profile.avatarUrl,
                      gateway: ref.read(accountGatewayProvider),
                      onSaved: (next) => setState(() {
                        _profile = next == null
                            ? _profile.copyWith(clearAvatar: true)
                            : _profile.copyWith(avatarUrl: next);
                      }),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      homiziText(context, name.isEmpty ? 'Your profile' : name),
                      key: const Key('profile-name'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    if (homiziRole == HomiziRole.broker) ...[
                      const SizedBox(height: 12),
                      const BrokerChip(),
                    ],
                    Text(
                      key: const Key('profile-initials'),
                      homiziText(
                        context,
                        _profile.occupation.trim().isEmpty
                            ? 'Add what you do'
                            : _profile.occupation.trim(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              homiziText(context, 'Profile ${score.filled} of ${score.total}'),
              key: const Key('profile-completion'),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: score.fraction,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                'Name, work, a short bio, a budget, a locality, and a role.',
              ),
            ),
            if (_loading) ...[
              const SizedBox(height: 16),
              Text(homiziText(context, 'Loading…')),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                homiziText(context, _error!),
                key: const Key('profile-error'),
              ),
            ],
            if (_note != null) ...[
              const SizedBox(height: 16),
              Text(homiziText(context, _note!), key: const Key('profile-note')),
            ],
            const SizedBox(height: 20),
            Text(
              homiziText(context, 'Role'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (role != null)
              SegmentedButton<AccountRole>(
                key: const Key('profile-role'),
                segments: [
                  ButtonSegment(
                    value: AccountRole.tenant,
                    label: Text(homiziText(context, 'Tenant')),
                  ),
                  ButtonSegment(
                    value: AccountRole.host,
                    label: Text(homiziText(context, 'Host')),
                  ),
                  ButtonSegment(
                    value: AccountRole.both,
                    label: Text(homiziText(context, 'Both')),
                  ),
                ],
                selected: {role},
                onSelectionChanged: (next) => unawaited(_role(next.first)),
              ),
            ListTile(
              key: const Key('profile-change-role'),
              contentPadding: EdgeInsets.zero,
              title: Text(homiziText(context, 'Change role')),
              subtitle: Text(
                homiziText(
                  context,
                  homiziRole == null
                      ? 'Choose how you use HOMIZI'
                      : homiziRoleLabel(homiziRole),
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.role),
            ),
            ListTile(
              key: const Key('profile-edit-requirements'),
              contentPadding: EdgeInsets.zero,
              title: Text(homiziText(context, 'Edit what you need')),
              subtitle: Text(
                homiziText(context, 'City, budget, home, and how you live.'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.requirement),
            ),
            if (homiziRole == HomiziRole.host ||
                homiziRole == HomiziRole.broker)
              ListTile(
                key: const Key('profile-host-options'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  homiziText(
                    context,
                    homiziRole == HomiziRole.broker
                        ? 'Broker tools'
                        : 'Host options',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                  homiziRole == HomiziRole.broker
                      ? RoutePaths.brokerRegister
                      : RoutePaths.hostOptions,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              homiziText(context, copy?.languageTitle ?? 'Language'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              key: const Key('profile-language'),
              segments: [
                ButtonSegment(
                  value: 'en',
                  label: Text(
                    homiziText(context, copy?.languageEnglish ?? 'English'),
                  ),
                ),
                ButtonSegment(
                  value: 'hi',
                  label: Text(
                    homiziText(context, copy?.languageHindi ?? 'Hindi'),
                  ),
                ),
              ],
              selected: {locale.languageCode},
              onSelectionChanged: (next) {
                ref.read(localeProvider.notifier).setCode(next.first);
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('profile-open-settings'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined),
              title: Text(homiziText(context, 'Settings')),
              subtitle: Text(
                homiziText(
                  context,
                  'Account, verification, notifications, privacy, payments, and help.',
                ),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.settings),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(homiziText(context, 'Tenant profile')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.tenantProfile),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(homiziText(context, 'Host profile')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RoutePaths.hostProfile),
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(context, 'My activity'),
              key: const Key('profile-activity'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _ActivityBlock(
              title: 'Saved',
              count: _activity.savedCount,
              onOpen: () => context.go(RoutePaths.saved),
              lines: [
                for (final place in _activity.saved)
                  '${place.title} · ${place.place}',
              ],
            ),
            _ActivityBlock(
              title: 'Recently viewed',
              count: _activity.viewedAvailable ? _activity.viewedCount : null,
              empty: 'No homes viewed yet.',
              onOpen: () => context.push(RoutePaths.recentlyViewed),
              lines: [
                for (final place in _activity.viewed)
                  '${place.title} · ${place.place}',
              ],
            ),
            _ActivityBlock(
              title: 'Requests',
              count: _activity.requestCount,
              onOpen: () => context.push(RoutePaths.requirement),
              lines: [
                for (final request in _activity.requests)
                  '${request.city} · ${formatInr(request.budgetMinInr)} to ${formatInr(request.budgetMaxInr)}',
              ],
            ),
            _ActivityBlock(
              title: 'Visits',
              count: _activity.visitCount,
              lines: [
                for (final visit in _activity.visits)
                  '${_visitLabel(visit.status)} · ${visit.onIso}',
              ],
            ),
            _ActivityBlock(
              title: 'Matches',
              count: _activity.matchCount,
              onOpen: () => context.go(RoutePaths.matches),
              lines: [for (final match in _activity.matches) match.name],
            ),
          ],
        ),
      ),
    );
  }
}

String _visitLabel(String status) {
  return switch (status) {
    'requested' => 'Requested',
    'accepted' => 'Accepted',
    'declined' => 'Declined',
    'cancelled' => 'Cancelled',
    'rescheduled' => 'Rescheduled',
    'completed' => 'Completed',
    _ => status,
  };
}

class _ActivityBlock extends StatelessWidget {
  const _ActivityBlock({
    required this.title,
    required this.count,
    required this.lines,
    this.empty,
    this.onOpen,
  });

  final String title;
  final int? count;
  final List<String> lines;
  final String? empty;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Card.filled(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    homiziText(context, title),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  count == null ? '—' : '$count',
                  key: Key(
                    'activity-${title.toLowerCase().replaceAll(' ', '-')}',
                  ),
                ),
              ],
            ),
            if (lines.isEmpty) ...[
              const SizedBox(height: 6),
              Text(homiziText(context, empty ?? 'Nothing here yet.')),
            ] else
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(homiziText(context, line)),
                ),
            if (onOpen != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onOpen,
                  child: Text(homiziText(context, 'Open')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
