import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/owner/owner_rules.dart';

/// Inbox of interests and visit requests. Status is a word. No contact fields.
class OwnerLeadsSheet extends ConsumerStatefulWidget {
  const OwnerLeadsSheet({
    required this.leads,
    required this.controller,
    super.key,
  });

  final List<OwnerLead> leads;
  final ScrollController controller;

  @override
  ConsumerState<OwnerLeadsSheet> createState() => _OwnerLeadsSheetState();
}

class _OwnerLeadsSheetState extends ConsumerState<OwnerLeadsSheet> {
  late List<OwnerLead> _leads;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _leads = [...widget.leads];
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
        _leads = [
          for (final item in _leads)
            if (item.id == updated.id) updated else item,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            homiziText(context, 'Lead marked ${ownerLeadStatusLabel(status)}.'),
          ),
        ),
      );
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
    return Column(
      key: const Key('owner-leads-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(context, 'Leads'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                homiziText(
                  context,
                  'Interests and visit requests on this home.',
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              if (_leads.isEmpty)
                Text(homiziText(context, 'No leads yet.'))
              else
                for (final lead in _leads) ...[
                  const SizedBox(height: 12),
                  _LeadCard(
                    lead: lead,
                    busy: _busyId == lead.id,
                    onStatus: (status) => unawaited(_setStatus(lead, status)),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.lead,
    required this.busy,
    required this.onStatus,
  });

  final OwnerLead lead;
  final bool busy;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final latest = lead.audit.isEmpty ? null : lead.audit.last;
    return Card.outlined(
      key: Key('lead-${lead.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, lead.nameLabel),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    homiziText(context, ownerLeadKindLabel(lead.kind)),
                  ),
                  backgroundColor: HomiziColors.mist,
                  side: const BorderSide(color: HomiziColors.line),
                ),
                Chip(
                  key: Key('lead-status-${lead.id}'),
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    homiziText(context, ownerLeadStatusLabel(lead.status)),
                  ),
                  backgroundColor: HomiziColors.mist,
                  side: const BorderSide(color: HomiziColors.line),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              key: Key('lead-response-${lead.id}'),
              homiziText(context, ownerLeadResponseLabel(lead)),
            ),
            if (latest != null) ...[
              const SizedBox(height: 4),
              Text(homiziText(context, ownerLeadAuditLabel(latest))),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final status in const ['new', 'replied', 'closed'])
                  _StatusButton(
                    leadId: lead.id,
                    status: status,
                    selected: lead.status == status,
                    enabled: !busy,
                    onPressed: () => onStatus(status),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.leadId,
    required this.status,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final String leadId;
  final String status;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = ownerLeadStatusLabel(status);
    return OutlinedButton(
      key: Key('lead-mark-$leadId-$status'),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        foregroundColor: const WidgetStatePropertyAll(HomiziColors.ink),
        backgroundColor: WidgetStatePropertyAll(
          selected ? HomiziColors.accentWash : HomiziColors.white,
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: selected ? HomiziColors.accent : HomiziColors.line),
        ),
      ),
      onPressed: enabled ? onPressed : null,
      child: Text(homiziText(context, label)),
    );
  }
}
