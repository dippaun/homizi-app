import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';
import 'package:homizi/features/trust/user_badges.dart';

/// The signed-in person's badges. Aadhaar and face appear only when the
/// server says they are verified.
class TrustBadgeSection extends ConsumerStatefulWidget {
  const TrustBadgeSection({super.key});

  @override
  ConsumerState<TrustBadgeSection> createState() => _TrustBadgeSectionState();
}

class _TrustBadgeSectionState extends ConsumerState<TrustBadgeSection> {
  UserBadges _badges = const UserBadges();
  var _loading = true;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('verification-section'),
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
            'Aadhaar verified and Face verified appear only after the server confirms them. HOMIZI stores the result, the time, the Digio request id, and the last 4 digits.',
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const LinearProgressIndicator()
        else
          TrustBadgeRow(badges: _badges),
        if (!_loading && !_badges.anyIdentity) ...[
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Not verified yet'),
            key: const Key('verification-unverified'),
          ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('open-verification'),
            onPressed: () => context.push(RoutePaths.verifyIdentity),
            child: Text(homiziText(context, 'Verify identity')),
          ),
        ),
        if (_note != null) ...[
          const SizedBox(height: 8),
          Text(homiziText(context, _note!), key: const Key('trust-badge-note')),
        ],
      ],
    );
  }
}
