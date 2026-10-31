import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/agreements/agreement_gateway.dart';
import 'package:homizi/features/agreements/agreement_providers.dart';
import 'package:homizi/features/agreements/domain/agreement_rules.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';

class AgreementsScreen extends ConsumerStatefulWidget {
  const AgreementsScreen({super.key});

  @override
  ConsumerState<AgreementsScreen> createState() => _AgreementsScreenState();
}

class _AgreementsScreenState extends ConsumerState<AgreementsScreen> {
  final _title = TextEditingController(text: 'Koramangala leave and licence');
  final _rent = TextEditingController(text: '22000');
  final _deposit = TextEditingController(text: '80000');
  final _term = TextEditingController(text: '11');
  final _draftRef = TextEditingController();
  var _busy = false;
  String? _note;
  List<AgreementRecord> _rows = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _title.dispose();
    _rent.dispose();
    _deposit.dispose();
    _term.dispose();
    _draftRef.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await ref.read(agreementGatewayProvider).listMine();
    if (mounted) {
      setState(() => _rows = rows);
    }
  }

  String get _matchId {
    final matches = ref.read(discoveryProvider).matches;
    if (matches.isNotEmpty) {
      return matches.first.matchId;
    }
    return 'demo-match-lst_koramangala';
  }

  Future<void> _create() async {
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Agreement saved',
        detail: 'The draft stays on this device for the demo.',
      );
      return;
    }
    final rent = int.tryParse(_rent.text.trim());
    final deposit = int.tryParse(_deposit.text.trim()) ?? 0;
    final term = int.tryParse(_term.text.trim());
    final body = agreementDraftBody(
      title: _title.text.trim(),
      rentInr: rent ?? 0,
      depositInr: deposit,
      termMonths: term ?? 0,
    );
    final problem = validateAgreementDraft(
      title: _title.text,
      body: body,
      rentInr: rent,
      termMonths: term,
    );
    if (problem != null) {
      setState(() => _note = problem);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(agreementGatewayProvider)
          .createDraft(
            matchId: _matchId,
            title: _title.text.trim(),
            body: body,
            tenantName: 'You',
            ownerName: 'Owner',
            sourceDraftId: _draftRef.text.trim().isEmpty
                ? null
                : _draftRef.text.trim(),
          );
      if (mounted) {
        setState(() => _note = 'Draft saved. It is not stamped or registered.');
      }
      await _load();
    } on AgreementFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _run(
    Future<AgreementRecord> Function() action,
    String note,
  ) async {
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Agreement saved',
        detail: 'The signature stays on this device for the demo.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        setState(() => _note = note);
      }
      await _load();
    } on AgreementFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Rent agreement')),
      ),
      body: HomiziFrame(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              homiziText(
                context,
                'Send the draft for e-sign to both people on the match. Demo mode signs on this device and does not stamp the agreement.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Title'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('agreement-rent'),
              controller: _rent,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Monthly rent (INR)'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _deposit,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Deposit (INR)'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _term,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Term (months)'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _draftRef,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Draft reference'),
                helperText: homiziText(
                  context,
                  'Optional. Paste a Tools draft id if you saved one.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('agreement-create'),
              onPressed: _busy ? null : () => unawaited(_create()),
              child: Text(homiziText(context, 'Create draft')),
            ),
            if (_note != null) ...[
              const SizedBox(height: 12),
              Text(
                homiziText(context, _note!),
                key: const Key('agreement-note'),
              ),
            ],
            const SizedBox(height: 20),
            for (final row in _rows) ...[
              Card(
                color: HomiziColors.white,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, row.title),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(homiziText(context, row.status.label)),
                      if (row.stampAmountInr != null)
                        Text(formatInr(row.stampAmountInr!)),
                      if (row.providerReference != null)
                        Text(row.providerReference!),
                      Wrap(
                        children: [
                          if (row.status == AgreementStatus.draft)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(
                                      _run(
                                        () => ref
                                            .read(agreementGatewayProvider)
                                            .sendForSignature(row.id),
                                        'Sent for signature.',
                                      ),
                                    ),
                              child: Text(
                                homiziText(context, 'Send for e-sign'),
                              ),
                            ),
                          if (row.isDemo &&
                              demoStatusAfterSign(
                                    current: row.status,
                                    role: 'tenant',
                                    provider: row.provider,
                                  ) !=
                                  null)
                            TextButton(
                              key: const Key('agreement-sign-tenant'),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(
                                      _run(
                                        () => ref
                                            .read(agreementGatewayProvider)
                                            .demoSign(row.id, role: 'tenant'),
                                        'Tenant signature recorded in the demo.',
                                      ),
                                    ),
                              child: Text(
                                homiziText(context, 'Sign as tenant (demo)'),
                              ),
                            ),
                          if (row.isDemo &&
                              demoStatusAfterSign(
                                    current: row.status,
                                    role: 'owner',
                                    provider: row.provider,
                                  ) !=
                                  null)
                            TextButton(
                              key: const Key('agreement-sign-owner'),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(
                                      _run(
                                        () => ref
                                            .read(agreementGatewayProvider)
                                            .demoSign(row.id, role: 'owner'),
                                        'Owner signature recorded in the demo.',
                                      ),
                                    ),
                              child: Text(
                                homiziText(context, 'Sign as owner (demo)'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
