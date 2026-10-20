import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/tools/domain/deposit_math.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';
import 'package:homizi/features/tools/tools_gateway.dart';
import 'package:homizi/features/tools/tools_providers.dart';

class DepositScreen extends ConsumerStatefulWidget {
  const DepositScreen({super.key});

  @override
  ConsumerState<DepositScreen> createState() => _DepositScreenState();
}

class _DepositScreenState extends ConsumerState<DepositScreen> {
  final _label = TextEditingController();
  final _paid = TextEditingController();
  final _due = TextEditingController();
  final _deductionLabel = TextEditingController();
  final _deductionAmount = TextEditingController();
  String? _openId;
  var _busy = false;
  String? _note;
  List<DepositTracker> _rows = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _label.dispose();
    _paid.dispose();
    _due.dispose();
    _deductionLabel.dispose();
    _deductionAmount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(toolsGatewayProvider).loadDeposits();
      if (!mounted) {
        return;
      }
      setState(() => _rows = rows);
    } on ToolsFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _note = error.message);
    }
  }

  DepositTracker? get _open {
    for (final row in _rows) {
      if (row.id == _openId) {
        return row;
      }
    }
    return null;
  }

  Future<void> _save() async {
    final paid = wholeRupees(_paid.text);
    final dueText = _due.text.trim();
    final due = dueText.isEmpty ? null : parseDay(dueText);
    if (dueText.isNotEmpty && due == null) {
      setState(
        () => _note = 'Enter the refund date as YYYY-MM-DD, or leave it blank.',
      );
      return;
    }
    if (paid == null) {
      setState(() => _note = 'Enter the deposit in whole rupees.');
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await ref
          .read(toolsGatewayProvider)
          .saveDeposit(
            propertyLabel: _label.text,
            depositPaidInr: paid,
            refundDueOn: due,
          );
      if (!mounted) {
        return;
      }
      _label.clear();
      _paid.clear();
      _due.clear();
      setState(() {
        _rows = [saved, ..._rows];
        _openId = saved.id;
        _note = 'Deposit saved. HOMIZI did not move this money.';
      });
    } on ToolsFailure catch (error) {
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

  Future<void> _deduct() async {
    final open = _open;
    final amount = wholeRupees(_deductionAmount.text);
    if (open == null || amount == null) {
      setState(() => _note = 'Enter a deduction in whole rupees.');
      return;
    }
    setState(() => _busy = true);
    try {
      final deduction = await ref
          .read(toolsGatewayProvider)
          .addDeduction(
            trackerId: open.id,
            label: _deductionLabel.text,
            amountInr: amount,
          );
      if (!mounted) {
        return;
      }
      _deductionLabel.clear();
      _deductionAmount.clear();
      setState(() {
        _rows = [
          for (final row in _rows)
            if (row.id == open.id)
              DepositTracker(
                id: row.id,
                propertyLabel: row.propertyLabel,
                depositPaidInr: row.depositPaidInr,
                refundDueOn: row.refundDueOn,
                deductions: [...row.deductions, deduction],
              )
            else
              row,
        ];
        _note = 'Deduction added.';
      });
    } on ToolsFailure catch (error) {
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

  Future<void> _remind() async {
    final open = _open;
    if (open == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final saved = await ref.read(toolsGatewayProvider).remindDeposit(open.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _note = saved
            ? 'Reminder added to notifications. No phone alert was sent.'
            : 'System notifications are off, so no reminder was added.';
      });
    } on ToolsFailure catch (error) {
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
    final open = _open;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Deposit tracker')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'Record a deposit you already paid. The reminder stays inside HOMIZI.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('deposit-label'),
            controller: _label,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Home'),
              hintText: homiziText(context, 'Koramangala 5th Block'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('deposit-paid'),
            controller: _paid,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Deposit paid'),
              hintText: '84000',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('deposit-due'),
            controller: _due,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Refund due date'),
              hintText: '2026-12-01',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('deposit-save'),
            onPressed: _busy ? null : () => unawaited(_save()),
            child: Text(homiziText(context, 'Save deposit')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(homiziText(context, _note!), key: const Key('deposit-note')),
          ],
          const SizedBox(height: 20),
          for (final row in _rows)
            Card.outlined(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                key: Key('deposit-${row.id}'),
                title: Text(row.propertyLabel),
                subtitle: Text(
                  homiziText(context, 'Refund due ${formatInr(row.refundInr)}'),
                  key: Key('deposit-refund-${row.id}'),
                ),
                onTap: () => setState(() => _openId = row.id),
              ),
            ),
          if (open != null) ...[
            Text(
              open.propertyLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                'Paid ${formatInr(open.depositPaidInr)} · deductions ${formatInr(open.deductionsInr)}',
              ),
            ),
            if (deductionsExceedDeposit(
              open.depositPaidInr,
              open.deductionsInr,
            ))
              Text(
                homiziText(
                  context,
                  'Deductions are higher than the deposit. The refund shown is zero.',
                ),
              ),
            for (final deduction in open.deductions)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${deduction.label} · ${formatInr(deduction.amountInr)}',
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('deduction-label'),
              controller: _deductionLabel,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Deduction'),
                hintText: homiziText(context, 'Painting'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('deduction-amount'),
              controller: _deductionAmount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Amount'),
                hintText: '8000',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('deduction-add'),
              onPressed: _busy ? null : () => unawaited(_deduct()),
              child: Text(homiziText(context, 'Add deduction')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('deposit-remind'),
              onPressed: _busy ? null : () => unawaited(_remind()),
              child: Text(homiziText(context, 'Remind me in the app')),
            ),
          ],
        ],
      ),
    );
  }
}
