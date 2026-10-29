import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';

class TenantVisitsScreen extends ConsumerStatefulWidget {
  const TenantVisitsScreen({super.key});

  @override
  ConsumerState<TenantVisitsScreen> createState() => _TenantVisitsScreenState();
}

class _TenantVisitsScreenState extends ConsumerState<TenantVisitsScreen> {
  ProfileActivity? _activity;
  String? _error;
  var _loading = true;

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
      final activity = await ref.read(profileHubGatewayProvider).loadActivity();
      if (!mounted) {
        return;
      }
      setState(() {
        _activity = activity;
        _loading = false;
      });
    } on ProfileHubFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visits = _activity?.visits ?? const <ActivityVisit>[];
    return Scaffold(
      key: const Key('tenant-visits-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Visits')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            homiziText(context, 'Times you asked to see a home'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'A visit is a time, not a street address. The building stays hidden until the visit is agreed.',
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null) ...[
            Text(homiziText(context, _error!)),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('tenant-visits-retry'),
              onPressed: () => unawaited(_load()),
              child: Text(homiziText(context, 'Try again')),
            ),
          ] else if (visits.isEmpty)
            Text(
              homiziText(
                context,
                'No visits yet. Match with a home, then ask for a time.',
              ),
            )
          else
            for (var index = 0; index < visits.length; index++)
              _VisitCard(visit: visits[index], index: index),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('tenant-visits-chats'),
            onPressed: () => context.go(RoutePaths.matches),
            child: Text(homiziText(context, 'Open chats')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('tenant-visits-explore'),
            onPressed: () => context.go(RoutePaths.explore),
            child: Text(homiziText(context, 'Explore homes')),
          ),
        ],
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, required this.index});

  final ActivityVisit visit;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('tenant-visit-$index'),
      elevation: 0,
      color: HomiziColors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: ListTile(
        leading: const Icon(Icons.event_outlined, color: HomiziColors.accent),
        title: Text(homiziText(context, _statusLabel(visit.status))),
        subtitle: Text(_visitDay(visit.onIso)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _openVisit(context, visit),
      ),
    );
  }
}

void _openVisit(BuildContext context, ActivityVisit visit) {
  final listingId = visit.listingId;
  if (listingId != null && listingId.isNotEmpty) {
    context.push(RoutePaths.listing(listingId));
    return;
  }
  final matchId = visit.matchId;
  if (matchId != null && matchId.isNotEmpty) {
    context.push(RoutePaths.chat(matchId, title: visit.listingTitle));
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'requested' => 'Requested',
    'accepted' || 'agreed' => 'Agreed',
    'declined' => 'Declined',
    'cancelled' => 'Cancelled',
    'rescheduled' => 'Rescheduled',
    'completed' => 'Completed',
    _ => _titleCase(status),
  };
}

String _titleCase(String status) {
  final trimmed = status.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1).toLowerCase()}';
}

String _visitDay(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) {
    return iso;
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (month == null || day == null || month < 1 || month > 12) {
    return iso;
  }
  return '$day ${months[month - 1]} ${parts[0]}';
}
