import 'package:flutter/material.dart';

const _reasons = <String>[
  'Spam',
  'Harassment',
  'Scam',
  'Fake listing',
  'Inappropriate',
  'Other',
];

class ReportBlockScreen extends StatefulWidget {
  const ReportBlockScreen({
    required this.targetType,
    required this.targetId,
    super.key,
  });

  final String targetType;
  final String targetId;

  @override
  State<ReportBlockScreen> createState() => _ReportBlockScreenState();
}

class _ReportBlockScreenState extends State<ReportBlockScreen> {
  String _reason = _reasons.first;
  final _details = TextEditingController();
  var _block = true;
  String? _confirmation;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Target: ${widget.targetType} ${widget.targetId}'),
          const SizedBox(height: 8),
          const Text(
            'The person you report is not told who filed it. This demo keeps the report in memory only. The reports table hides it from the reported account.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: [
              for (final reason in _reasons)
                DropdownMenuItem(value: reason, child: Text(reason)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _reason = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _details,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(labelText: 'Details (optional)'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _block,
            onChanged: (value) => setState(() => _block = value ?? false),
            title: const Text('Also block this account'),
            subtitle: const Text(
              'A block stops new interest, matches, and contact visibility in both directions.',
            ),
          ),
          FilledButton(
            key: const Key('submit-report'),
            onPressed: () {
              setState(() {
                _confirmation = _block
                    ? 'Report noted in this session and the account is blocked locally. A moderator queue is not connected yet.'
                    : 'Report noted in this session. A moderator queue is not connected yet.';
              });
            },
            child: const Text('Submit report'),
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
