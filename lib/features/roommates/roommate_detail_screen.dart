import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/roommates/compatibility_sheet.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/roommate_card.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/features/trust/trust_badge_row.dart';

class RoommateDetailScreen extends ConsumerStatefulWidget {
  const RoommateDetailScreen({required this.seekerId, super.key});

  final String seekerId;

  @override
  ConsumerState<RoommateDetailScreen> createState() =>
      _RoommateDetailScreenState();
}

class _RoommateDetailScreenState extends ConsumerState<RoommateDetailScreen> {
  RoommateSeeker? _seeker;
  var _loading = true;
  String? _error;
  var _busy = false;

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
    try {
      final seeker = await ref
          .read(roommateGatewayProvider)
          .byId(widget.seekerId);
      if (!mounted) {
        return;
      }
      setState(() {
        _seeker = seeker;
        _loading = false;
        if (seeker == null) {
          _error = 'This person is not available.';
        }
      });
    } on RoommateFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _score() async {
    final seeker = _seeker;
    if (seeker == null) {
      return;
    }
    try {
      final score = await ref.read(roommateGatewayProvider).breakdown(seeker);
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: HomiziColors.white,
        builder: (context) =>
            RoommateBreakdownSheet(seeker: seeker, score: score),
      );
    } on RoommateFailure catch (error) {
      _note(error.message);
    }
  }

  Future<void> _act({required bool pass}) async {
    final seeker = _seeker;
    if (seeker == null || _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final gateway = ref.read(roommateGatewayProvider);
      final message = pass
          ? await gateway.pass(seeker)
          : await gateway.like(seeker);
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _note(message);
    } on RoommateFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _busy = false);
      _note(error.message);
    }
  }

  void _note(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(homiziText(context, message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seeker = _seeker;
    return MinTouchScope(
      child: Scaffold(
        key: const Key('flatmate-person'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          title: Text(homiziText(context, seeker?.name ?? 'Roommate')),
        ),
        body: _body(seeker),
      ),
    );
  }

  Widget _body(RoommateSeeker? seeker) {
    if (_loading) {
      return const LoadingState(message: 'Opening this profile…');
    }
    if (_error != null || seeker == null) {
      return ErrorState(
        title: 'Profile unavailable',
        message: _error ?? 'This person is not available.',
        onRetry: _load,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 1.4,
            child: ListingPhoto(asset: seeker.photoRef),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                seeker.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            CompatibilityChip(
              seekerId: seeker.id,
              score: seeker.score,
              onPressed: _score,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text('${seeker.age} · ${seeker.profession}'),
        if (seeker.trust.anyIdentity) ...[
          const SizedBox(height: 12),
          IdentityBadgeRow(badges: seeker.trust),
        ],
        const SizedBox(height: 12),
        Text(seeker.localityLabel),
        const SizedBox(height: 4),
        Text(seeker.budgetLabel),
        const SizedBox(height: 4),
        Text(homiziText(context, seeker.moveInLabel)),
        if (seeker.traits.thoughts.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'Looking for'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(seeker.traits.thoughts.trim()),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('flatmate-compatibility'),
          onPressed: _score,
          child: Text(homiziText(context, 'Compatibility')),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('flatmate-interested'),
          onPressed: _busy ? null : () => unawaited(_act(pass: false)),
          child: Text(homiziText(context, 'Interested')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('flatmate-pass'),
          onPressed: _busy ? null : () => unawaited(_act(pass: true)),
          child: Text(homiziText(context, 'Pass')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('flatmate-open-chats'),
          onPressed: () => context.go(RoutePaths.matches),
          child: Text(homiziText(context, 'Chats')),
        ),
      ],
    );
  }
}
