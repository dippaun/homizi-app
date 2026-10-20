import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/host/host_leads_screen.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/owner/owner_rules.dart';

/// Visit requests on the host's own homes. The street stays hidden.
class HostVisitsScreen extends ConsumerStatefulWidget {
  const HostVisitsScreen({super.key});

  @override
  ConsumerState<HostVisitsScreen> createState() => _HostVisitsScreenState();
}

class _HostVisitsScreenState extends ConsumerState<HostVisitsScreen> {
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
        _rows = [
          for (final row in rows)
            if (row.lead.kind == 'visit') row,
        ];
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

  Future<void> _reply(String leadId) async {
    setState(() => _busyId = leadId);
    try {
      final updated = await ref
          .read(ownerGatewayProvider)
          .setLeadStatus(leadId, 'replied');
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
      key: const Key('host-visits-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Visits'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  homiziText(
                    context,
                    'Agree a visit in the app. The street address stays hidden until you accept.',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('host-visits-chats'),
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
                  Text(
                    homiziText(context, 'No visit requests yet.'),
                    key: const Key('host-visits-empty'),
                  ),
                ] else
                  for (final row in _rows) ...[
                    const SizedBox(height: 12),
                    Card.outlined(
                      key: Key('host-visit-${row.lead.id}'),
                      color: HomiziColors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              homiziText(context, row.lead.nameLabel),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(homiziText(context, row.place)),
                            const SizedBox(height: 8),
                            Text(
                              homiziText(
                                context,
                                ownerLeadStatusLabel(row.lead.status),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              key: Key('host-visit-reply-${row.lead.id}'),
                              onPressed:
                                  _busyId != null ||
                                      row.lead.status == 'replied'
                                  ? null
                                  : () => unawaited(_reply(row.lead.id)),
                              child: Text(homiziText(context, 'Mark replied')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
              ],
            ),
    );
  }
}
