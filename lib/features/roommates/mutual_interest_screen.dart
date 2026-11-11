import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/roommates/compatibility_sheet.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/roommate_card.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/shell/min_touch.dart';

class MutualInterestScreen extends ConsumerStatefulWidget {
  const MutualInterestScreen({super.key});

  @override
  ConsumerState<MutualInterestScreen> createState() =>
      _MutualInterestScreenState();
}

class _MutualInterestScreenState extends ConsumerState<MutualInterestScreen> {
  var _rows = const <RoommateSeeker>[];
  var _loading = true;
  String? _error;

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
      final rows = await ref.read(roommateGatewayProvider).mutual();
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
        _loading = false;
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

  Future<void> _score(RoommateSeeker seeker) async {
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MinTouchScope(
      child: Scaffold(
        key: const Key('flatmate-mutual-screen'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, 'Mutual interest')),
        ),
        body: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const LoadingState(message: 'Checking mutual interest…');
    }
    if (_error != null) {
      return ErrorState(
        title: 'Interest did not load',
        message: _error!,
        onRetry: _load,
      );
    }
    if (_rows.isEmpty) {
      return EmptyState(
        title: 'No mutual interest yet',
        message:
            'When you and someone else are both interested, they show up here. Contact stays hidden.',
        actionLabel: 'See roommates',
        onAction: () => context.go(RoutePaths.roommates),
      );
    }
    return ListView.separated(
      key: const Key('flatmate-mutual-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: _rows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final seeker = _rows[index];
        return RoommateCard(
          seeker: seeker,
          onScore: () => _score(seeker),
          onOpen: () => context.push(RoutePaths.flatmatePerson(seeker.id)),
        );
      },
    );
  }
}
