import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// The signed-in person's mock badges, plus the staging ID toggle.
class TrustBadgeSection extends ConsumerStatefulWidget {
  const TrustBadgeSection({super.key});

  @override
  ConsumerState<TrustBadgeSection> createState() => _TrustBadgeSectionState();
}

class _TrustBadgeSectionState extends ConsumerState<TrustBadgeSection> {
  UserBadges _badges = const UserBadges();
  var _loading = true;
  var _busy = false;
  String? _note;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final badges = await ref.read(ownerGatewayProvider).myBadges();
      if (!mounted) {
        return;
      }
      setState(() {
        _badges = badges;
        _loading = false;
      });
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _note = error.message;
      });
    }
  }

  Future<void> _toggle(bool enabled) async {
    setState(() => _busy = true);
    try {
      final badges = await ref
          .read(ownerGatewayProvider)
          .setDemoIdVerified(enabled: enabled);
      if (!mounted) {
        return;
      }
      setState(() {
        _badges = badges;
        _busy = false;
        _note = enabled
            ? 'Demo ID badge is on. No identity document was collected.'
            : 'Demo ID badge is off.';
      });
    } on OwnerFailure catch (error) {
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
    final showToggle = ref.watch(appConfigProvider).showsDemoIdBadge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Verification'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'These badges are mock checks. HOMIZI does not collect an Aadhaar number, a passport, or a face scan.',
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const LinearProgressIndicator()
        else
          TrustBadgeRow(badges: _badges),
        if (showToggle) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('demo-id-badge'),
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'ID verified (demo)')),
            subtitle: Text(
              homiziText(
                context,
                'Staging only. Turning this on does not verify an identity document.',
              ),
            ),
            value: _badges.idVerifiedDemo,
            onChanged: _busy ? null : (value) => unawaited(_toggle(value)),
          ),
        ],
        if (_note != null) ...[
          const SizedBox(height: 8),
          Text(homiziText(context, _note!), key: const Key('trust-badge-note')),
        ],
      ],
    );
  }
}
