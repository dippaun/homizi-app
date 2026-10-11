import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/safety/domain/safety_rules.dart';
import 'package:homizi/features/safety/safety_gateway.dart';
import 'package:homizi/features/safety/safety_providers.dart';

class ReportBlockScreen extends ConsumerStatefulWidget {
  const ReportBlockScreen({
    required this.targetType,
    required this.targetId,
    this.blockedUserId,
    super.key,
  });

  final String targetType;
  final String targetId;
  final String? blockedUserId;

  @override
  ConsumerState<ReportBlockScreen> createState() => _ReportBlockScreenState();
}

class _ReportBlockScreenState extends ConsumerState<ReportBlockScreen> {
  String _reason = reportReasonValues.first;
  final _details = TextEditingController();
  late bool _block = widget.blockedUserId != null;
  var _busy = false;
  String? _confirmation;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(safetyGatewayProvider)
          .submit(
            targetType: widget.targetType,
            targetId: widget.targetId,
            reason: _reason,
            details: _details.text,
            blockedUserId: widget.blockedUserId,
            alsoBlock: _block,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _confirmation = result.message;
      });
    } on SafetyFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _confirmation = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetLabel = switch (normalizeReportTarget(widget.targetType)) {
      'user' => 'a person',
      'property' => 'a listing',
      'listing_requirement' => 'a requirement',
      'message' => 'a message',
      _ => 'this item',
    };
    final canBlock =
        widget.blockedUserId != null &&
        safetySubjectIdOk(widget.blockedUserId!);
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('You are reporting $targetLabel.'),
          const SizedBox(height: 8),
          const Text(
            'The person you report is not told who filed it. A moderator queue is not connected. The report is stored for your account, without a phone number, an email address, or a street address.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [
              for (final reason in reportReasonValues)
                DropdownMenuItem(
                  value: reason,
                  child: Text(reportReasonLabel(reason)),
                ),
            ],
            onChanged: _busy
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _reason = value);
                    }
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('report-details'),
            controller: _details,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              labelText: 'Details (optional)',
              helperText: 'Do not include a phone number or an email address.',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: canBlock && _block,
            onChanged: !canBlock || _busy
                ? null
                : (value) => setState(() => _block = value ?? false),
            title: const Text('Also block this account'),
            subtitle: Text(
              canBlock
                  ? 'A block stops new interest, messages, and contact visibility in both directions.'
                  : 'This report has no account id to block.',
            ),
          ),
          FilledButton(
            key: const Key('submit-report'),
            onPressed: _busy ? null : () => unawaited(_submit()),
            child: Text(_busy ? 'Sending…' : 'Submit report'),
          ),
          if (_confirmation != null) ...[
            const SizedBox(height: 16),
            Text(_confirmation!, key: const Key('report-confirmation')),
          ],
        ],
      ),
    );
  }
}
