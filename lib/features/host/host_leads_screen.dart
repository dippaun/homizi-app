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

class HostLeadRow {
  const HostLeadRow({required this.lead, required this.place});

  final OwnerLead lead;
  final String place;
}

Future<List<HostLeadRow>> loadHostLeadRows(OwnerGateway gateway) async {
  final listings = await gateway.myListings();
  final rows = <HostLeadRow>[];
  for (final listing in listings) {
    final leads = await gateway.leads(listing.id);
    for (final lead in leads) {
      rows.add(HostLeadRow(lead: lead, place: listing.title));
    }
  }
  rows.sort((a, b) => b.lead.createdAt.compareTo(a.lead.createdAt));
  return rows;
}

/// Every interest and visit request across the host's homes.
class HostLeadsScreen extends ConsumerStatefulWidget {
  const HostLeadsScreen({super.key});

  @override
  ConsumerState<HostLeadsScreen> createState() => _HostLeadsScreenState();
}

class _HostLeadsScreenState extends ConsumerState<HostLeadsScreen> {
  List<HostLeadRow> _rows = const [];
  var _loading = true;
  String? _error;
  String? _busyId;

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
      final rows = await loadHostLeadRows(ref.read(ownerGatewayProvider));
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
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _setStatus(OwnerLead lead, String status) async {
    if (_busyId != null || lead.status == status) {
      return;
    }
    setState(() => _busyId = lead.id);
    try {
      final updated = await ref
          .read(ownerGatewayProvider)
          .setLeadStatus(lead.id, status);
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = [
          for (final row in _rows)
            if (row.lead.id == updated.id)
              HostLeadRow(lead: updated, place: row.place)
            else
              row,
        ];
      });
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('host-leads-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Lead inbox')),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  homiziText(
                    context,
                    'Interests and visit requests on your homes in India. Phone numbers and email addresses stay hidden.',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('host-leads-chats'),
                  onPressed: () => context.go(RoutePaths.matches),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(homiziText(context, 'Open chats')),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(homiziText(context, _error!)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => unawaited(_load()),
                    child: Text(homiziText(context, 'Try again')),
                  ),
                ] else if (_rows.isEmpty) ...[
                  const SizedBox(height: 16),
                  Text(homiziText(context, 'No leads yet.')),
                ] else
                  for (final row in _rows) ...[
                    const SizedBox(height: 12),
                    _LeadTile(
                      row: row,
                      busy: _busyId == row.lead.id,
                      onStatus: (status) =>
                          unawaited(_setStatus(row.lead, status)),
                    ),
                  ],
              ],
            ),
    );
  }
}

class _LeadTile extends StatelessWidget {
  const _LeadTile({
    required this.row,
    required this.busy,
    required this.onStatus,
  });

  final HostLeadRow row;
  final bool busy;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final lead = row.lead;
    return Card.outlined(
      key: Key('host-lead-${lead.id}'),
      color: HomiziColors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, lead.nameLabel),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(homiziText(context, row.place)),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                '${ownerLeadKindLabel(lead.kind)} · ${ownerLeadStatusLabel(lead.status)}',
              ),
            ),
            const SizedBox(height: 4),
            Text(homiziText(context, ownerLeadResponseLabel(lead))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in const ['new', 'replied', 'closed'])
                  OutlinedButton(
                    key: Key('host-lead-${lead.id}-$status'),
                    onPressed: busy ? null : () => onStatus(status),
                    child: Text(
                      homiziText(context, ownerLeadStatusLabel(status)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
