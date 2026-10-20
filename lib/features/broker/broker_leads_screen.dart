import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_page.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/owner/owner_rules.dart';

class _LeadRow {
  const _LeadRow({required this.lead, required this.listingTitle});

  final OwnerLead lead;
  final String listingTitle;
}

class BrokerLeadsScreen extends ConsumerStatefulWidget {
  const BrokerLeadsScreen({super.key});

  @override
  ConsumerState<BrokerLeadsScreen> createState() => _BrokerLeadsScreenState();
}

class _BrokerLeadsScreenState extends ConsumerState<BrokerLeadsScreen> {
  List<_LeadRow> _rows = const [];
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
      final gateway = ref.read(ownerGatewayProvider);
      final listings = await gateway.myListings();
      final rows = <_LeadRow>[];
      for (final listing in listings) {
        final leads = await gateway.leads(listing.id);
        for (final lead in leads) {
          rows.add(_LeadRow(lead: lead, listingTitle: listing.title));
        }
      }
      rows.sort((a, b) => b.lead.createdAt.compareTo(a.lead.createdAt));
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } on OwnerFailure catch (error) {
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
    return Scaffold(
      key: const Key('broker-leads-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Leads'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  homiziText(
                    context,
                    'Interests and visit requests on homes you manage. No phone number is shown here.',
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    homiziText(context, _error!),
                    key: const Key('broker-leads-error'),
                  ),
                if (_rows.isEmpty)
                  Text(
                    homiziText(context, 'No leads yet.'),
                    key: const Key('broker-leads-empty'),
                  ),
                for (final row in _rows)
                  BrokerTapCard(
                    cardKey: Key('broker-lead-card-${row.lead.id}'),
                    onTap: () =>
                        context.push(RoutePaths.brokerLead(row.lead.id)),
                    child: _LeadSummary(row: row),
                  ),
                OutlinedButton(
                  key: const Key('broker-leads-listings'),
                  onPressed: () => context.go(RoutePaths.listings),
                  child: Text(homiziText(context, 'Manage listings')),
                ),
              ],
            ),
    );
  }
}

class BrokerLeadScreen extends ConsumerStatefulWidget {
  const BrokerLeadScreen({required this.leadId, super.key});

  final String leadId;

  @override
  ConsumerState<BrokerLeadScreen> createState() => _BrokerLeadScreenState();
}

class _BrokerLeadScreenState extends ConsumerState<BrokerLeadScreen> {
  _LeadRow? _row;
  var _loading = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final gateway = ref.read(ownerGatewayProvider);
      final listings = await gateway.myListings();
      _LeadRow? found;
      for (final listing in listings) {
        final leads = await gateway.leads(listing.id);
        for (final lead in leads) {
          if (lead.id == widget.leadId) {
            found = _LeadRow(lead: lead, listingTitle: listing.title);
            break;
          }
        }
        if (found != null) {
          break;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _row = found;
        _loading = false;
        _error = found == null ? 'This lead is not on your listing.' : null;
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

  Future<void> _status(String status) async {
    setState(() => _busy = true);
    try {
      final updated = await ref
          .read(ownerGatewayProvider)
          .setLeadStatus(widget.leadId, status);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        final current = _row;
        _row = current == null
            ? null
            : _LeadRow(lead: updated, listingTitle: current.listingTitle);
      });
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        key: Key('broker-lead-screen'),
        backgroundColor: HomiziColors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final row = _row;
    if (row == null) {
      return BrokerPage(
        screenKey: const Key('broker-lead-screen'),
        title: 'Lead',
        children: [
          Text(
            homiziText(context, _error ?? 'This lead is not on your listing.'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('broker-lead-home'),
            onPressed: () => context.go(RoutePaths.brokerLeads),
            child: Text(homiziText(context, 'Back to leads')),
          ),
        ],
      );
    }
    final lead = row.lead;
    return BrokerPage(
      screenKey: const Key('broker-lead-screen'),
      title: 'Lead',
      children: [
        _LeadSummary(row: row),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(homiziText(context, _error!)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('broker-lead-reply'),
          onPressed: _busy ? null : () => unawaited(_status('replied')),
          child: Text(homiziText(context, 'Mark replied')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('broker-lead-close'),
          onPressed: _busy ? null : () => unawaited(_status('closed')),
          child: Text(homiziText(context, 'Close lead')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('broker-lead-chat'),
          onPressed: () => context.push(
            RoutePaths.chat(
              'broker-lead-${lead.id}',
              name: lead.nameLabel,
              title: row.listingTitle,
            ),
          ),
          child: Text(homiziText(context, 'Open chat')),
        ),
      ],
    );
  }
}

class _LeadSummary extends StatelessWidget {
  const _LeadSummary({required this.row});

  final _LeadRow row;

  @override
  Widget build(BuildContext context) {
    final lead = row.lead;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, lead.nameLabel),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(homiziText(context, row.listingTitle)),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            '${ownerLeadKindLabel(lead.kind)} · ${ownerLeadStatusLabel(lead.status)}',
          ),
          key: Key('broker-lead-status-${lead.id}'),
        ),
      ],
    );
  }
}
