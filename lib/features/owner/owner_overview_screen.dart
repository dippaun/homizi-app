import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/owner/owner_rules.dart';
import 'package:homizi/features/trust/trust_badge_section.dart';

/// Stats, leads, and visits. The listing list stays on My listings.
class OwnerOverviewScreen extends ConsumerStatefulWidget {
  const OwnerOverviewScreen({super.key});

  @override
  ConsumerState<OwnerOverviewScreen> createState() =>
      _OwnerOverviewScreenState();
}

class _OwnerOverviewScreenState extends ConsumerState<OwnerOverviewScreen> {
  var _loading = true;
  String? _error;
  var _views = 0;
  var _saves = 0;
  var _interests = 0;
  var _visits = 0;
  var _live = 0;
  List<OwnerLead> _leads = const [];

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
      final gateway = ref.read(ownerGatewayProvider);
      final listings = await gateway.myListings();
      final leads = <OwnerLead>[];
      for (final listing in listings) {
        try {
          leads.addAll(await gateway.leads(listing.id));
        } on OwnerFailure {
          // A home with no lead row still counts in the totals.
        }
      }
      leads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) {
        return;
      }
      setState(() {
        _views = listings.fold(0, (sum, row) => sum + row.views);
        _saves = listings.fold(0, (sum, row) => sum + row.saves);
        _interests = listings.fold(0, (sum, row) => sum + row.interests);
        _visits = listings.fold(0, (sum, row) => sum + row.visitRequests);
        _live = listings.where((row) => row.chip == 'live').length;
        _leads = leads;
        _loading = false;
      });
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visits = [
      for (final lead in _leads)
        if (lead.kind == 'visit') lead,
    ];
    return Scaffold(
      key: const Key('owner-overview'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Owner dashboard')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                const TrustBadgeSection(),
                const SizedBox(height: 16),
                Text(
                  homiziText(context, '$_live live homes'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  key: const Key('owner-overview-stats'),
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Stat(label: '$_views views'),
                    _Stat(label: '$_saves saves'),
                    _Stat(label: '$_interests interests'),
                    _Stat(label: '$_visits visit requests'),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  homiziText(context, 'Leads'),
                  key: const Key('owner-overview-leads'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_error != null)
                  Text(homiziText(context, _error!))
                else if (_leads.isEmpty)
                  Text(homiziText(context, 'No leads yet.'))
                else
                  for (final lead in _leads.take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(homiziText(context, lead.displayName)),
                      subtitle: Text(
                        homiziText(
                          context,
                          '${ownerLeadKindLabel(lead.kind)} · ${ownerLeadStatusLabel(lead.status)}',
                        ),
                      ),
                    ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.push(RoutePaths.hostLeads),
                  child: Text(homiziText(context, 'Open lead inbox')),
                ),
                const SizedBox(height: 20),
                Text(
                  homiziText(context, 'Visits'),
                  key: const Key('owner-overview-visits'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (visits.isEmpty)
                  Text(homiziText(context, 'No visit requests yet.'))
                else
                  for (final lead in visits.take(5))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.event_outlined,
                        color: HomiziColors.accent,
                      ),
                      title: Text(homiziText(context, lead.displayName)),
                      subtitle: Text(
                        homiziText(context, ownerLeadStatusLabel(lead.status)),
                      ),
                    ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.push(RoutePaths.hostVisits),
                  child: Text(homiziText(context, 'Open visits')),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.go(RoutePaths.listings),
                  child: Text(homiziText(context, 'My listings')),
                ),
              ],
            ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(homiziText(context, label)),
      backgroundColor: HomiziColors.accentWash,
      side: const BorderSide(color: HomiziColors.line),
    );
  }
}
