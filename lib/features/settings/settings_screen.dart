import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/locale_controller.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/moderation/moderation_providers.dart';
import 'package:homizi/features/push/push_providers.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  var _deleting = false;
  var _matchAlerts = true;

  Future<void> _deleteAccount() async {
    var understood = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return MinTouchScope(
              child: AlertDialog(
                title: Text(homiziText(context, 'Delete this account?')),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(
                        context,
                        'This removes the profile, listings, photos, messages, and contact row on this device, or on the connected local server. It does not call a payment provider, an identity provider, or a production backup.',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: understood,
                      onChanged: (value) =>
                          setDialogState(() => understood = value ?? false),
                      title: Text(
                        homiziText(
                          context,
                          'I understand this cannot be undone here.',
                        ),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(homiziText(context, 'Cancel')),
                  ),
                  FilledButton(
                    key: const Key('delete-account-confirm'),
                    onPressed: understood
                        ? () => Navigator.pop(context, true)
                        : null,
                    child: Text(homiziText(context, 'Delete account')),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (accepted != true || !mounted) {
      return;
    }
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Profile saved',
        detail: 'This demo account stays signed in.',
      );
      return;
    }
    setState(() => _deleting = true);
    try {
      final message = await ref.read(accountGatewayProvider).deleteAccount();
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(
            homiziText(context, message),
            key: const Key('account-deletion-note'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(homiziText(context, 'OK')),
            ),
          ],
        ),
      );
      ref.read(sessionProvider.notifier).completeAccountDeletion();
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(homiziText(context, error.message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(homiziText(context, 'OK')),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(sessionProvider);
    final locale = ref.watch(localeProvider);
    final copy = AppLocalizations.of(context);
    final staff = ref.watch(staffStatusProvider).asData?.value ?? false;
    final role = switch (session.role) {
      AccountRole.tenant => 'Tenant',
      AccountRole.host => 'Host',
      AccountRole.both => 'Tenant and host',
      null => 'Not chosen',
    };
    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, 'Settings')),
        ),
        body: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: BrandLockup(markSize: 28),
            ),
            const _SettingsHeading('Account'),
            ListTile(
              title: Text(homiziText(context, 'Signed in as')),
              subtitle: Text(
                homiziText(
                  context,
                  session.contact.isEmpty ? 'Unknown' : session.contact,
                ),
              ),
            ),
            ListTile(
              title: Text(homiziText(context, 'Role')),
              subtitle: Text(homiziText(context, role)),
            ),
            ListTile(
              key: const Key('open-profile-hub'),
              title: Text(homiziText(context, 'Profile')),
              subtitle: Text(
                homiziText(context, 'Activity, role, and language.'),
              ),
              onTap: () => context.push(RoutePaths.profile),
            ),
            ListTile(
              title: Text(homiziText(context, 'Tenant profile')),
              onTap: () => context.push(RoutePaths.tenantProfile),
            ),
            ListTile(
              title: Text(homiziText(context, 'Host profile')),
              onTap: () => context.push(RoutePaths.hostProfile),
            ),
            ListTile(
              title: Text(homiziText(context, 'Your requirement')),
              onTap: () => context.push(RoutePaths.requirement),
            ),
            ListTile(
              key: const Key('settings-find-home'),
              title: Text(homiziText(context, 'Find a home')),
              onTap: () => context.go(RoutePaths.explore),
            ),
            ListTile(
              key: const Key('settings-list-home'),
              title: Text(homiziText(context, 'List your home')),
              onTap: () => context.push(RoutePaths.listingEditor),
            ),
            if (session.role == AccountRole.host ||
                session.role == AccountRole.both) ...[
              ListTile(
                key: const Key('for-owners-entry'),
                title: Text(homiziText(context, 'For owners')),
                subtitle: Text(
                  homiziText(context, 'List your home free. Zero brokerage.'),
                ),
                onTap: () => context.push(RoutePaths.forOwners),
              ),
              ListTile(
                key: const Key('owner-dashboard-entry'),
                title: Text(homiziText(context, 'My listings')),
                subtitle: Text(
                  homiziText(
                    context,
                    'Drafts, live homes, pauses, and rented listings.',
                  ),
                ),
                onTap: () => context.push(RoutePaths.ownerDashboard),
              ),
            ],
            ListTile(
              title: Text(homiziText(context, 'Create a listing')),
              onTap: () => context.push(RoutePaths.listingEditor),
            ),
            ListTile(
              key: const Key('settings-swipe'),
              title: Text(homiziText(context, 'Swipe to match')),
              onTap: () => context.go(RoutePaths.discover),
            ),
            ListTile(
              key: const Key('settings-matches'),
              title: Text(homiziText(context, 'Matches')),
              onTap: () => context.go(RoutePaths.matches),
            ),
            ListTile(
              key: const Key('settings-saved'),
              title: Text(homiziText(context, 'Saved')),
              onTap: () => context.go(RoutePaths.saved),
            ),
            ListTile(
              title: Text(
                homiziText(context, copy?.languageTitle ?? 'Language'),
              ),
              subtitle: Text(
                homiziText(
                  context,
                  copy?.languageHint ??
                      'English and Hindi cover the buttons, help, and messages in this app. Demo home titles follow the same language.',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(kMinTouchTarget, kMinTouchTarget),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
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
            ),
            ListTile(
              title: Text(homiziText(context, 'Log out')),
              onTap: () =>
                  unawaited(ref.read(sessionProvider.notifier).signOut()),
            ),
            ListTile(
              key: const Key('delete-account'),
              title: Text(homiziText(context, 'Delete account')),
              subtitle: Text(
                homiziText(
                  context,
                  'Removes listing photos, calls delete_own_account, then signs out. Production backups are not included.',
                ),
              ),
              enabled: !_deleting,
              onTap: _deleting ? null : () => unawaited(_deleteAccount()),
            ),
            const _SettingsHeading('Verification'),
            ListTile(
              key: const Key('open-verify'),
              title: Text(homiziText(context, 'Verify identity')),
              onTap: () => context.push(RoutePaths.verifyIdentity),
            ),
            const _SettingsHeading('Notifications'),
            ListTile(
              title: Text(homiziText(context, 'Notifications')),
              subtitle: Text(
                homiziText(
                  context,
                  'Matches, messages, and visits. No phone, email, or street address.',
                ),
              ),
              onTap: () => context.push(RoutePaths.notifications),
            ),
            SwitchListTile(
              title: Text(homiziText(context, 'Match alerts on this device')),
              subtitle: Text(
                homiziText(
                  context,
                  ref.watch(pushGatewayProvider).configured
                      ? 'Match, chat, and visit alerts on this device.'
                      : 'Push stays off until a Firebase project is compiled into this build. The in-app inbox still works.',
                ),
              ),
              value: _matchAlerts,
              onChanged: (value) {
                setState(() => _matchAlerts = value);
                unawaited(ref.read(pushGatewayProvider).setEnabled(value));
              },
            ),
            const _SettingsHeading('Privacy & safety'),
            SwitchListTile(
              key: const Key('analytics-sharing'),
              title: Text(homiziText(context, 'Product analytics')),
              subtitle: Text(
                homiziText(
                  context,
                  'Counts of screens and actions stay in this database. Phone numbers, email addresses, and names are not included. Turn this off to stop new events.',
                ),
              ),
              value: !ref.watch(analyticsOptOutProvider),
              onChanged: (value) => ref
                  .read(analyticsOptOutProvider.notifier)
                  .setOptedOut(!value),
            ),
            ListTile(
              title: Text(homiziText(context, 'Help and safety')),
              onTap: () => context.push(RoutePaths.help),
            ),
            const _SettingsHeading('Payments'),
            ListTile(
              key: const Key('open-payments'),
              title: Text(homiziText(context, 'Pay rent (test mode)')),
              onTap: () => context.push(RoutePaths.payments),
            ),
            ListTile(
              title: Text(homiziText(context, 'Rent agreement')),
              onTap: () => context.push(RoutePaths.agreements),
            ),
            const _SettingsHeading('Help & legal'),
            ListTile(
              key: const Key('settings-help'),
              title: Text(homiziText(context, 'Help')),
              onTap: () => context.push(RoutePaths.help),
            ),
            ListTile(
              title: Text(homiziText(context, 'Privacy')),
              onTap: () => context.push(RoutePaths.privacy),
            ),
            ListTile(
              title: Text(homiziText(context, 'Terms')),
              onTap: () => context.push(RoutePaths.terms),
            ),
            ListTile(
              title: Text(homiziText(context, 'Support')),
              onTap: () => context.push(RoutePaths.support),
            ),
            const _SettingsHeading('App'),
            ListTile(
              title: Text(homiziText(context, 'Environment')),
              subtitle: Text(
                homiziText(
                  context,
                  '${config.environment.name} · ${config.connectsToSupabase ? 'Supabase configured' : 'demo mode, no project connected'}',
                ),
              ),
            ),
            ListTile(
              title: Text(homiziText(context, 'Policy version')),
              subtitle: Text(
                homiziText(context, session.policyVersion ?? 'Not accepted'),
              ),
            ),
            ListTile(
              key: const Key('open-tools'),
              title: Text(homiziText(context, 'Tools')),
              subtitle: Text(
                homiziText(
                  context,
                  'Receipts, agreement draft, split, checklist, and deposit.',
                ),
              ),
              onTap: () => context.push(RoutePaths.tools),
            ),
            ListTile(
              key: const Key('settings-services'),
              title: Text(homiziText(context, 'Home services')),
              subtitle: Text(
                homiziText(
                  context,
                  'Packers, cleaning, repairs. A HOMIZI partner contacts you.',
                ),
              ),
              onTap: () => context.push(RoutePaths.services),
            ),
            if (staff)
              ListTile(
                key: const Key('open-moderation'),
                title: Text(homiziText(context, 'Review reports')),
                subtitle: Text(
                  homiziText(
                    context,
                    'Staff accounts can hide a listing or suspend an account. No phone number or email is shown.',
                  ),
                ),
                onTap: () => context.push(RoutePaths.moderation),
              ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeading extends StatelessWidget {
  const _SettingsHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        homiziText(context, title),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
