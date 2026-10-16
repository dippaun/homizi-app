import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';

class TenantProfileScreen extends ConsumerStatefulWidget {
  const TenantProfileScreen({super.key});

  @override
  ConsumerState<TenantProfileScreen> createState() =>
      _TenantProfileScreenState();
}

class _TenantProfileScreenState extends ConsumerState<TenantProfileScreen> {
  final _name = TextEditingController();
  final _occupation = TextEditingController();
  final _bio = TextEditingController();
  VerificationStatus _status = VerificationStatus.notStarted;
  ViewStatus _view = ViewStatus.loading;
  String? _error;
  String? _note;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_refreshHeader);
    unawaited(_load());
  }

  void _refreshHeader() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _name.removeListener(_refreshHeader);
    _name.dispose();
    _occupation.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _view = ViewStatus.loading);
    try {
      final profile = await ref
          .read(accountGatewayProvider)
          .loadTenantProfile();
      if (!mounted) {
        return;
      }
      _name.text = profile.displayName;
      _occupation.text = profile.occupation;
      _bio.text = profile.bio;
      setState(() {
        _status = profile.verification;
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
          .saveTenantProfile(
            TenantProfile(
              displayName: _name.text,
              occupation: _occupation.text,
              bio: _bio.text,
              verification: _status,
            ),
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _note = 'Profile saved. Contact details were not part of this form.';
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

  Future<void> _mockVerify() async {
    setState(() => _busy = true);
    try {
      final status = await ref
          .read(accountGatewayProvider)
          .requestMockVerification();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _status = status;
        _note = mockVerificationMessage;
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
    final canQueue =
        _status == VerificationStatus.notStarted ||
        _status == VerificationStatus.rejected;
    final scheme = Theme.of(context).colorScheme;
    final name = _name.text.trim();
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(homiziText(context, 'Tenant profile')),
          ),
          if (_view != ViewStatus.ready)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AsyncStateBody(
                status: _view,
                loadingMessage: 'Loading your profile',
                emptyTitle: 'No profile yet',
                emptyMessage: 'Sign in to create your tenant profile.',
                errorTitle: 'Profile unavailable',
                errorMessage: _error ?? 'The profile could not be loaded.',
                onRetry: () => unawaited(_load()),
                child: const SizedBox.shrink(),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            HostAvatar(
                              name: name.isEmpty ? 'You' : name,
                              radius: 36,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    homiziText(
                                      context,
                                      name.isEmpty ? 'Tenant profile' : name,
                                    ),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  if (_occupation.text.trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      homiziText(
                                        context,
                                        _occupation.text.trim(),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  VerifiedBadge(label: _status.label),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      homiziText(
                        context,
                        'Only fields a match needs. Date of birth and contact details are not on this form.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('tenant-display-name'),
                      controller: _name,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: homiziText(context, 'Display name'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _occupation,
                      maxLength: 80,
                      decoration: InputDecoration(
                        labelText: homiziText(context, 'Occupation'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _bio,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: InputDecoration(
                        labelText: homiziText(context, 'Public bio'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(homiziText(context, 'Verification status')),
                      subtitle: Text(homiziText(context, _status.label)),
                    ),
                    if (_note != null)
                      Text(
                        homiziText(context, _note!),
                        key: const Key('tenant-profile-note'),
                      ),
                    const SizedBox(height: 12),
                    FilledButton(
                      key: const Key('save-tenant-profile'),
                      onPressed: _busy ? null : () => unawaited(_save()),
                      child: Text(
                        homiziText(context, _busy ? 'Saving…' : 'Save profile'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _busy || !canQueue
                          ? null
                          : () => unawaited(_mockVerify()),
                      child: Text(
                        homiziText(context, 'Start mock verification'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      homiziText(
                        context,
                        'This does not call a verification provider and does not upload a document. The server only moves the status to mock pending.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
