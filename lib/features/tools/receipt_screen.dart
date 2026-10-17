import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/tools/domain/tool_pdf.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';
import 'package:homizi/features/tools/pdf_delivery.dart';
import 'package:homizi/features/tools/tools_gateway.dart';
import 'package:homizi/features/tools/tools_providers.dart';

class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({super.key});

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  final _tenant = TextEditingController();
  final _owner = TextEditingController();
  final _address = TextEditingController();
  final _rent = TextEditingController();
  final _pan = TextEditingController();
  late int _startMonth = DateTime.now().month;
  late int _startYear = DateTime.now().year;
  late int _endMonth = DateTime.now().month;
  late int _endYear = DateTime.now().year;
  var _mode = 'upi';
  var _busy = false;
  String? _note;
  List<RentReceipt> _saved = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _tenant.dispose();
    _owner.dispose();
    _address.dispose();
    _rent.dispose();
    _pan.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(toolsGatewayProvider).loadReceipts();
      if (!mounted) {
        return;
      }
      setState(() => _saved = rows);
    } on ToolsFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _note = error.message);
    }
  }

  Future<void> _save({RentReceipt? again}) async {
    final receipt = again ?? _fromForm();
    if (receipt == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final saved =
          again ?? await ref.read(toolsGatewayProvider).saveReceipt(receipt);
      if (!mounted) {
        return;
      }
      if (again == null) {
        _tenant.clear();
        _owner.clear();
        _address.clear();
        _rent.clear();
        _pan.clear();
        setState(() {
          _saved = [saved, ..._saved];
          _note = 'Receipt saved. You can download it again below.';
        });
      }
      final bytes = await buildReceiptPdf(saved);
      try {
        await deliverPdf(bytes: bytes, filename: 'homizi-rent-receipt.pdf');
      } catch (_) {
        if (mounted) {
          setState(() {
            _note = again == null
                ? 'Receipt saved. The PDF share sheet did not open.'
                : 'The PDF share sheet did not open.';
          });
        }
      }
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

  RentReceipt? _fromForm() {
    final pan = normalizePan(_pan.text);
    if (pan == '') {
      setState(() {
        _note = 'Owner PAN must look like ABCDE1234F, or stay blank.';
      });
      return null;
    }
    final start = DateTime(_startYear, _startMonth);
    final end = DateTime(_endYear, _endMonth);
    final error = receiptError(
      tenantName: _tenant.text,
      ownerName: _owner.text,
      propertyAddress: _address.text,
      monthlyRentInr: wholeRupees(_rent.text),
      periodStart: start,
      periodEnd: end,
      ownerPan: pan,
      paymentMode: _mode,
    );
    if (error != null) {
      setState(() => _note = error);
      return null;
    }
    return RentReceipt(
      id: '',
      tenantName: _tenant.text.trim(),
      ownerName: _owner.text.trim(),
      propertyAddress: _address.text.trim(),
      monthlyRentInr: wholeRupees(_rent.text)!,
      periodStart: start,
      periodEnd: end,
      ownerPan: pan,
      paymentMode: _mode,
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final years = [for (var year = 2025; year <= 2028; year++) year];
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Rent receipt'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'For a payment you already made. HOMIZI does not collect the rent.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('receipt-tenant'),
            controller: _tenant,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Tenant'),
              hintText: homiziText(context, 'Ananya Iyer'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('receipt-owner'),
            controller: _owner,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Owner'),
              hintText: homiziText(context, 'Rohan Mehta'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('receipt-address'),
            controller: _address,
            minLines: 2,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Property address'),
              hintText: homiziText(
                context,
                '18, 4th Cross, Koramangala 5th Block, Bengaluru',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('receipt-rent'),
            controller: _rent,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Monthly rent'),
              hintText: '28000',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _month(_startMonth, (value) => _startMonth = value),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _year(years, _startYear, (value) => _startYear = value),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _month(_endMonth, (value) => _endMonth = value)),
              const SizedBox(width: 8),
              Expanded(
                child: _year(years, _endYear, (value) => _endYear = value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('receipt-pan'),
            controller: _pan,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Owner PAN, optional'),
              hintText: homiziText(
                context,
                'Leave blank if you do not have it',
              ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: const Key('receipt-mode'),
            initialValue: _mode,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Payment mode'),
            ),
            items: [
              for (final mode in paymentModes)
                DropdownMenuItem(
                  value: mode,
                  child: Text(homiziText(context, paymentModeLabel(mode))),
                ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _mode = value);
              }
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('receipt-save'),
            onPressed: _busy ? null : () => unawaited(_save()),
            child: Text(homiziText(context, 'Generate PDF')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(homiziText(context, _note!), key: const Key('receipt-note')),
          ],
          const SizedBox(height: 24),
          Text(
            homiziText(context, 'Past receipts'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_saved.isEmpty)
            Text(
              homiziText(
                context,
                'No receipts yet. A receipt stays on your account so you can download it again.',
              ),
              key: const Key('receipt-empty'),
            )
          else
            for (final receipt in _saved)
              Card.filled(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  key: Key('receipt-${receipt.id}'),
                  title: Text(receipt.tenantName),
                  subtitle: Text(
                    '${formatInr(receipt.monthlyRentInr)} · ${monthSpan(receipt.periodStart, receipt.periodEnd)}',
                  ),
                  trailing: IconButton(
                    key: Key('receipt-download-${receipt.id}'),
                    tooltip: homiziText(context, 'Download'),
                    onPressed: _busy
                        ? null
                        : () => unawaited(_save(again: receipt)),
                    icon: const Icon(Icons.download_outlined),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _month(int selected, ValueChanged<int> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: homiziText(context, 'Month')),
      items: [
        for (var month = 1; month <= 12; month++)
          DropdownMenuItem(
            value: month,
            child: Text(homiziText(context, monthLabels[month - 1])),
          ),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => onChanged(value));
        }
      },
    );
  }

  Widget _year(List<int> years, int selected, ValueChanged<int> onChanged) {
    return DropdownButtonFormField<int>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: homiziText(context, 'Year')),
      items: [
        for (final year in years)
          DropdownMenuItem(value: year, child: Text('$year')),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => onChanged(value));
        }
      },
    );
  }
}
