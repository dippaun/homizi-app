import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/tools/domain/tool_pdf.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';
import 'package:homizi/features/tools/pdf_delivery.dart';
import 'package:homizi/features/tools/tools_gateway.dart';
import 'package:homizi/features/tools/tools_providers.dart';

class AgreementScreen extends ConsumerStatefulWidget {
  const AgreementScreen({super.key});

  @override
  ConsumerState<AgreementScreen> createState() => _AgreementScreenState();
}

class _AgreementScreenState extends ConsumerState<AgreementScreen> {
  final _licensor = TextEditingController();
  final _licensee = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController(text: 'Bengaluru');
  final _rent = TextEditingController();
  final _deposit = TextEditingController(text: '0');
  final _maintenance = TextEditingController(text: '0');
  final _start = TextEditingController(text: '2026-11-01');
  var _busy = false;
  String? _note;
  List<AgreementDraft> _saved = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _licensor.dispose();
    _licensee.dispose();
    _address.dispose();
    _city.dispose();
    _rent.dispose();
    _deposit.dispose();
    _maintenance.dispose();
    _start.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(toolsGatewayProvider).loadAgreements();
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

  Future<void> _save({AgreementDraft? again}) async {
    final draft = again ?? _fromForm();
    if (draft == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final saved =
          again ?? await ref.read(toolsGatewayProvider).saveAgreement(draft);
      if (!mounted) {
        return;
      }
      if (again == null) {
        setState(() {
          _saved = [saved, ..._saved];
          _note =
              'Draft saved. The PDF is marked as not stamped or registered.';
        });
      }
      final bytes = await buildAgreementPdf(saved);
      try {
        await deliverPdf(
          bytes: bytes,
          filename: 'homizi-leave-and-licence-draft.pdf',
        );
      } catch (_) {
        if (mounted) {
          setState(() {
            _note = 'Draft saved. The PDF share sheet did not open.';
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

  AgreementDraft? _fromForm() {
    final start = parseDay(_start.text);
    if (start == null) {
      setState(() => _note = 'Enter the start date as YYYY-MM-DD.');
      return null;
    }
    final error = agreementError(
      licensorName: _licensor.text,
      licenseeName: _licensee.text,
      propertyAddress: _address.text,
      city: _city.text,
      monthlyRentInr: wholeRupees(_rent.text),
      depositInr: wholeRupees(_deposit.text),
      maintenanceInr: wholeRupees(_maintenance.text),
    );
    if (error != null) {
      setState(() => _note = error);
      return null;
    }
    return AgreementDraft(
      id: '',
      licensorName: _licensor.text.trim(),
      licenseeName: _licensee.text.trim(),
      propertyAddress: _address.text.trim(),
      city: _city.text.trim(),
      monthlyRentInr: wholeRupees(_rent.text)!,
      depositInr: wholeRupees(_deposit.text)!,
      maintenanceInr: wholeRupees(_maintenance.text)!,
      startDate: start,
      createdAt: DateTime.now().toUtc(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Agreement draft')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            key: const Key('agreement-watermark'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: HomiziColors.mist,
            child: Text(
              homiziText(context, agreementWatermark),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(
              context,
              'An 11-month leave and licence. HOMIZI does not stamp it or register it.',
            ),
          ),
          const SizedBox(height: 16),
          _field(
            _licensor,
            'Licensor (owner)',
            'agreement-licensor',
            'Rohan Mehta',
          ),
          _field(
            _licensee,
            'Licensee (tenant)',
            'agreement-licensee',
            'Ananya Iyer',
          ),
          _field(
            _address,
            'Property address',
            'agreement-address',
            '18, 4th Cross, Koramangala 5th Block, Bengaluru',
            lines: 2,
          ),
          _field(_city, 'City', 'agreement-city', 'Bengaluru'),
          _field(_rent, 'Monthly rent', 'agreement-rent', '28000'),
          _field(_deposit, 'Deposit', 'agreement-deposit', '84000'),
          _field(_maintenance, 'Maintenance', 'agreement-maintenance', '2000'),
          _field(_start, 'Start date', 'agreement-start', '2026-11-01'),
          FilledButton(
            key: const Key('agreement-save'),
            onPressed: _busy ? null : () => unawaited(_save()),
            child: Text(homiziText(context, 'Generate draft PDF')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(homiziText(context, _note!), key: const Key('agreement-note')),
          ],
          const SizedBox(height: 24),
          Text(
            homiziText(context, 'Saved drafts'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (_saved.isEmpty)
            Text(
              homiziText(context, 'No drafts yet.'),
              key: const Key('agreement-empty'),
            )
          else
            for (final draft in _saved)
              Card.filled(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  title: Text(draft.licenseeName),
                  subtitle: Text(
                    '${draft.city} · ${formatInr(draft.monthlyRentInr)} · 11 months',
                  ),
                  trailing: IconButton(
                    tooltip: homiziText(context, 'Download'),
                    onPressed: _busy
                        ? null
                        : () => unawaited(_save(again: draft)),
                    icon: const Icon(Icons.download_outlined),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String key,
    String hint, {
    int lines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key(key),
        controller: controller,
        minLines: lines,
        maxLines: lines,
        decoration: InputDecoration(
          labelText: homiziText(context, label),
          hintText: hint,
        ),
      ),
    );
  }
}
