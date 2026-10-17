import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/moderation/moderation_providers.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/services/service_lead_gateway.dart';
import 'package:homizi/features/services/service_providers.dart';

class StaffServiceLeadsScreen extends ConsumerStatefulWidget {
  const StaffServiceLeadsScreen({super.key});

  @override
  ConsumerState<StaffServiceLeadsScreen> createState() =>
      _StaffServiceLeadsScreenState();
}

class _StaffServiceLeadsScreenState
    extends ConsumerState<StaffServiceLeadsScreen> {
  var _loading = true;
  String? _note;
  List<ServiceLead> _rows = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final staff = await ref.read(moderationGatewayProvider).isStaff();
    if (!mounted) {
      return;
    }
    if (!staff) {
      setState(() {
        _loading = false;
        _note = 'You are not a staff account.';
      });
      return;
    }
    try {
      final rows = await ref.read(serviceLeadGatewayProvider).listForStaff();
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _rows = rows;
        _note = null;
      });
    } on ServiceLeadFailure catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _note = error.message;
        });
      }
    }
  }

  Future<void> _setStatus(ServiceLead lead, String status) async {
    try {
      await ref.read(serviceLeadGatewayProvider).updateStatus(lead.id, status);
      await _load();
    } on ServiceLeadFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Service requests'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  homiziText(
                    context,
                    'Requests from people who asked a HOMIZI partner to contact them. Phone numbers and email addresses are not shown.',
                  ),
                ),
                if (_note != null) ...[
                  const SizedBox(height: 12),
                  Text(homiziText(context, _note!)),
                ],
                if (_rows.isEmpty && _note == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(homiziText(context, 'No requests yet.')),
                  ),
                for (final lead in _rows)
                  Card(
                    color: HomiziColors.white,
                    child: ListTile(
                      title: Text(homiziText(context, lead.kind.label)),
                      subtitle: Text(
                        '${lead.fromLocality}${lead.toLocality == null ? '' : ' to ${lead.toLocality}'}, ${lead.city}',
                      ),
                      trailing: DropdownButton<String>(
                        value: lead.status,
                        items: [
                          for (final status in serviceLeadStatuses)
                            DropdownMenuItem(
                              value: status,
                              child: Text(
                                homiziText(context, switch (status) {
                                  'contacted' => 'Contacted',
                                  'closed' => 'Closed',
                                  _ => 'Requested',
                                }),
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            unawaited(_setStatus(lead, value));
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
