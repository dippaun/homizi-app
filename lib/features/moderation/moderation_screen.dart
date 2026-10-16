import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/moderation/domain/moderation_queue.dart';
import 'package:homizi/features/moderation/moderation_gateway.dart';
import 'package:homizi/features/moderation/moderation_providers.dart';
import 'package:homizi/features/safety/domain/safety_rules.dart';

class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  var _loading = true;
  var _busy = false;
  String? _note;
  List<ModerationReport> _reports = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({String? note}) async {
    final gateway = ref.read(moderationGatewayProvider);
    try {
      final staff = await gateway.isStaff();
      if (!mounted) {
        return;
      }
      if (!staff) {
        setState(() {
          _loading = false;
          _reports = const [];
          _note = 'You are not a staff account.';
        });
        return;
      }
      final reports = await gateway.listReports();
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _reports = reports;
        _note = note ?? _note;
      });
    } on ModerationFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _note = error.message;
      });
    }
  }

  Future<void> _run(Future<ModerationResult> Function() action) async {
    setState(() => _busy = true);
    try {
      final result = await action();
      if (!mounted) {
        return;
      }
      await _load(note: result.message);
    } on ModerationFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _note = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Review reports'))),
      body: _loading
          ? const LoadingState(message: 'Opening the queue…')
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  homiziText(
                    context,
                    'Open reports for a staff account. No phone number or email is shown.',
                  ),
                ),
                if (_note != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    homiziText(context, _note!),
                    key: const Key('moderation-note'),
                  ),
                ],
                const SizedBox(height: 16),
                if (_reports.isEmpty)
                  Text(homiziText(context, 'No reports are waiting.'))
                else
                  for (final report in _reports) ...[
                    _ReportCard(
                      report: report,
                      busy: _busy,
                      onReview: (status) => _run(
                        () => ref
                            .read(moderationGatewayProvider)
                            .reviewReport(report.id, status),
                      ),
                      onHide: () => _run(
                        () => ref
                            .read(moderationGatewayProvider)
                            .hideListing(report.targetId),
                      ),
                      onSuspend: () => _run(
                        () => ref
                            .read(moderationGatewayProvider)
                            .suspendUser(report.targetId),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.busy,
    required this.onReview,
    required this.onHide,
    required this.onSuspend,
  });

  final ModerationReport report;
  final bool busy;
  final Future<void> Function(String status) onReview;
  final Future<void> Function() onHide;
  final Future<void> Function() onSuspend;

  @override
  Widget build(BuildContext context) {
    final title =
        '${homiziText(context, moderationTargetLabel(report.targetType))} · ${homiziText(context, reportReasonLabel(report.reason))}';
    return Card.outlined(
      key: Key('moderation-report-${report.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, title),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(homiziText(context, _statusLabel(report.status))),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (report.status == 'open')
                  OutlinedButton(
                    key: Key('review-report-${report.id}-reviewing'),
                    onPressed: busy
                        ? null
                        : () => unawaited(onReview('reviewing')),
                    child: Text(homiziText(context, 'Mark reviewing')),
                  ),
                FilledButton(
                  key: Key('review-report-${report.id}-resolved'),
                  onPressed: busy
                      ? null
                      : () => unawaited(onReview('resolved')),
                  child: Text(homiziText(context, 'Resolve')),
                ),
                OutlinedButton(
                  key: Key('review-report-${report.id}-dismissed'),
                  onPressed: busy
                      ? null
                      : () => unawaited(onReview('dismissed')),
                  child: Text(homiziText(context, 'Dismiss')),
                ),
                if (report.canHideListing)
                  OutlinedButton(
                    key: Key('hide-listing-${report.id}'),
                    onPressed: busy ? null : () => unawaited(onHide()),
                    child: Text(homiziText(context, 'Hide listing')),
                  ),
                if (report.canSuspendUser)
                  OutlinedButton(
                    key: Key('suspend-user-${report.id}'),
                    onPressed: busy ? null : () => unawaited(onSuspend()),
                    child: Text(homiziText(context, 'Suspend account')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'reviewing' => 'Reviewing',
    'resolved' => 'Resolved',
    'dismissed' => 'Dismissed',
    _ => 'Open',
  };
}
