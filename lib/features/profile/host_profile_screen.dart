import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';

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
      final profile = await ref.read(accountGatewayProvider).loadHostProfile();
      if (!mounted) {
        return;
      }
      _company.text = profile.companyName;
      setState(() {
        _category = profile.category;
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
    setState(() => _busy = true);
    try {
      await ref
          .read(accountGatewayProvider)
          .saveHostProfile(
            HostProfile(category: _category, companyName: _company.text),
          );
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
      appBar: AppBar(title: const Text('Host profile')),
      body: AsyncStateBody(
        status: _view,
        loadingMessage: 'Loading your host profile',
        emptyTitle: 'No host profile yet',
        emptyMessage: 'Save a category when you are ready to list a home.',
        errorTitle: 'Host profile unavailable',
        errorMessage: _error ?? 'The host profile could not be loaded.',
        onRetry: () => unawaited(_load()),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Host category is a claim. A badge is not shown until a future review. Contact details stay in the private contact record.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Host category'),
              items: const [
                DropdownMenuItem(value: 'owner', child: Text('Owner')),
                DropdownMenuItem(value: 'broker', child: Text('Broker')),
                DropdownMenuItem(value: 'company', child: Text('Company')),
                DropdownMenuItem(value: 'flatmate', child: Text('Flatmate')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
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
              decoration: const InputDecoration(
                labelText: 'Company name (optional)',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save-host-profile'),
              onPressed: _busy ? null : () => unawaited(_save()),
              child: Text(_busy ? 'Saving…' : 'Save host profile'),
            ),
            if (_note != null) ...[
              const SizedBox(height: 12),
              Text(_note!, key: const Key('host-profile-note')),
            ],
          ],
        ),
      ),
    );
  }
}
