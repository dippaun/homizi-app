import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/profile/avatar_actions.dart';
import 'package:homizi/features/trust/trust_badge_section.dart';

class HostProfileScreen extends ConsumerStatefulWidget {
  const HostProfileScreen({super.key});

  @override
  ConsumerState<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends ConsumerState<HostProfileScreen> {
  final _company = TextEditingController();
  String _category = 'owner';
  ViewStatus _view = ViewStatus.loading;
  String? _error;
  String? _note;
  bool _busy = false;
  String? _avatar;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _company.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _view = ViewStatus.loading);
    try {
      final gateway = ref.read(accountGatewayProvider);
      final profile = await gateway.loadHostProfile();
      final tenant = await gateway.loadTenantProfile();
      if (!mounted) {
        return;
      }
      _company.text = profile.companyName;
      setState(() {
        _category = profile.category;
        _avatar = tenant.avatarUrl;
        _displayName = tenant.displayName;
        _view = ViewStatus.ready;
        _error = null;
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _view = ViewStatus.error;
        _error = error.message;
      });
    }
  }

  Future<void> _save() async {
    final profile = HostProfile(
      category: _category,
      companyName: _company.text,
    );
    final invalid = hostProfileSaveError(profile);
    if (invalid != null) {
      setState(() => _note = invalid);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(accountGatewayProvider).saveHostProfile(profile);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note =
            'Host profile saved as $_category. No badge is shown, and contact details stay private.';
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(homiziText(context, 'Host profile'))),
      body: AsyncStateBody(
        status: _view,
        loadingMessage: 'Loading your host profile',
        emptyTitle: 'No host profile yet',
        emptyMessage: 'Save a category when you are ready to list a home.',
        errorTitle: 'Host profile unavailable',
        errorMessage: _error ?? 'The host profile could not be loaded.',
        onRetry: () => unawaited(_load()),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfilePhotoRow(
                      name: _displayName.isEmpty ? 'Host' : _displayName,
                      photoRef: _avatar,
                      gateway: ref.read(accountGatewayProvider),
                      onSaved: (next) => setState(() => _avatar = next),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      homiziText(context, 'Host profile'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    VerifiedBadge(label: _hostCategoryLabel(_category)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              homiziText(
                context,
                'Host category is a claim you choose. Aadhaar and face badges come from verification. Contact details stay in the private contact record.',
              ),
            ),
            const SizedBox(height: 16),
            const TrustBadgeSection(),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Host category'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'owner',
                  child: Text(homiziText(context, 'Owner')),
                ),
                DropdownMenuItem(
                  value: 'broker',
                  child: Text(homiziText(context, 'Broker')),
                ),
                DropdownMenuItem(
                  value: 'company',
                  child: Text(homiziText(context, 'Company')),
                ),
                DropdownMenuItem(
                  value: 'flatmate',
                  child: Text(homiziText(context, 'Flatmate')),
                ),
                DropdownMenuItem(
                  value: 'other',
                  child: Text(homiziText(context, 'Other')),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('host-company'),
              controller: _company,
              maxLength: 120,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Company name (optional)'),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save-host-profile'),
              onPressed: _busy ? null : () => unawaited(_save()),
              child: Text(
                homiziText(context, _busy ? 'Saving…' : 'Save host profile'),
              ),
            ),
            if (_note != null) ...[
              const SizedBox(height: 12),
              Text(
                homiziText(context, _note!),
                key: const Key('host-profile-note'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _hostCategoryLabel(String category) {
  return switch (category) {
    'owner' => 'Owner',
    'broker' => 'Broker',
    'company' => 'Company',
    'flatmate' => 'Flatmate',
    _ => 'Other',
  };
}
