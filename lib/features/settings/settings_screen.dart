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
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
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
            return AlertDialog(
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
            );
          },
        );
      },
    );
    if (accepted != true || !mounted) {
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
    final role = switch (session.role) {
      AccountRole.tenant => 'Tenant',
      AccountRole.host => 'Host',
      AccountRole.both => 'Tenant and host',
      null => 'Not chosen',
    };
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Settings'))),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: BrandLockup(markSize: 28),
          ),
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
            title: Text(homiziText(context, 'Policy version')),
            subtitle: Text(
              homiziText(context, session.policyVersion ?? 'Not accepted'),
            ),
          ),
          const Divider(),
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
            title: Text(homiziText(context, 'Create a listing')),
            onTap: () => context.push(RoutePaths.listingEditor),
          ),
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
          ListTile(
            title: Text(homiziText(context, 'Help and safety')),
            onTap: () => context.push(RoutePaths.help),
          ),
          const Divider(),
          ListTile(
            title: Text(homiziText(context, copy?.languageTitle ?? 'Language')),
            subtitle: Text(
              homiziText(
                context,
                copy?.languageHint ?? 'English and Hindi cover the buttons, help, and messages in this app. Demo home titles follow the same language.',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
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
          const Divider(),
          SwitchListTile(
            title: Text(homiziText(context, 'Match alerts on this device')),
            subtitle: Text(
              homiziText(
                context,
                'Push delivery is not connected. This preference stays on this screen.',
              ),
            ),
            value: _matchAlerts,
            onChanged: (value) => setState(() => _matchAlerts = value),
          ),
          const Divider(),
          ListTile(
            key: const Key('delete-account'),
            title: Text(homiziText(context, 'Delete account')),
            subtitle: Text(
              homiziText(
                context,
                'Removes this account on the device or the connected local server. Production backups and vendors are not included.',
              ),
            ),
            enabled: !_deleting,
            onTap: _deleting ? null : () => unawaited(_deleteAccount()),
          ),
          ListTile(
            title: Text(homiziText(context, 'Log out')),
            onTap: () =>
                unawaited(ref.read(sessionProvider.notifier).signOut()),
          ),
        ],
      ),
    );
  }
}
