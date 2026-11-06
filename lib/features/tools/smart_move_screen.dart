import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/tools/domain/smart_move.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';

/// Smart Move: illustrative rent-to-own explainer for growing Indian cities.
class SmartMoveScreen extends ConsumerStatefulWidget {
  const SmartMoveScreen({super.key});

  @override
  ConsumerState<SmartMoveScreen> createState() => _SmartMoveScreenState();
}

class _SmartMoveScreenState extends ConsumerState<SmartMoveScreen> {
  final _rent = TextEditingController(text: '20000');
  final _years = TextEditingController(text: '5');
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _notes = TextEditingController();
  String _city = smartMoveCities.first;
  SmartMoveResult? _result;
  String? _calcNote;
  String? _formNote;
  var _busy = false;

  @override
  void dispose() {
    _rent.dispose();
    _years.dispose();
    _name.dispose();
    _contact.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _calculate() {
    final rent = wholeRupees(_rent.text);
    final years = int.tryParse(_years.text.trim());
    if (rent == null || rent <= 0) {
      setState(() {
        _result = null;
        _calcNote = 'Enter monthly rent in whole rupees.';
      });
      return;
    }
    if (years == null || years < 1 || years > 30) {
      setState(() {
        _result = null;
        _calcNote = 'Enter years between 1 and 30.';
      });
      return;
    }
    try {
      final result = smartMove(
        SmartMoveInput(monthlyRentInr: rent, years: years),
      );
      setState(() {
        _result = result;
        _calcNote = null;
      });
    } on ArgumentError catch (error) {
      setState(() {
        _result = null;
        _calcNote = error.message?.toString() ?? 'Could not calculate.';
      });
    }
  }

  Future<void> _submitInterest() async {
    final rent = wholeRupees(_rent.text) ?? _result?.monthlyRentInr;
    final problem = SmartMoveInterestStore.instance.validate(
      name: _name.text,
      city: _city,
      contact: _contact.text,
      monthlyRentInr: rent,
    );
    if (problem != null) {
      setState(() => _formNote = problem);
      return;
    }
    final rentInr = rent!;
    setState(() {
      _busy = true;
      _formNote = null;
    });
    try {
      SmartMoveInterestStore.instance.save(
        name: _name.text,
        city: _city,
        contact: _contact.text,
        monthlyRentInr: rentInr,
        notes: _notes.text,
      );
      if (!mounted) {
        return;
      }
      openDemoSuccess(
        context,
        title: 'Interest saved',
        detail:
            'Thanks. Smart Move is a concept only — not a financial offer or booking. '
            'We stored this on your device for the demo.',
      );
    } on ArgumentError catch (error) {
      if (mounted) {
        setState(() => _formNote = error.message?.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('smart-move-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Smart Move')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'Live now. Move later. Keep more of your rent.',
            ),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'Many people in Ahmedabad and other growing cities pay about '
              '₹20,000 rent but hesitate to buy a ₹15L–₹30L flat in case work '
              'forces a move. Smart Move is a Homizi concept: you live in a flat '
              'Homizi helps own; if you shift, Homizi can buy it back or move you '
              'to another home; and about 70% of the rent you paid could count '
              'back as a return instead of fully depreciating.',
            ),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: HomiziColors.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            key: const Key('smart-move-disclaimer'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HomiziColors.warningWash,
              borderRadius: BorderRadius.circular(HomiziSpace.radius),
              border: Border.all(color: HomiziColors.line),
            ),
            child: Text(
              homiziText(
                context,
                'Concept and illustrative numbers only. Not a financial offer, '
                'loan, investment product, or guaranteed return. No real payments '
                'run through Homizi here.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            homiziText(context, 'Illustrative calculator'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('smart-move-rent'),
            controller: _rent,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Monthly rent (₹)'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('smart-move-years'),
            controller: _years,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Years you might stay'),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('smart-move-calculate'),
            onPressed: _calculate,
            child: Text(homiziText(context, 'See rent vs return')),
          ),
          if (_calcNote != null) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, _calcNote!),
              key: const Key('smart-move-calc-note'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: HomiziColors.error,
              ),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            Card(
              key: const Key('smart-move-result'),
              elevation: 0,
              color: HomiziColors.soft,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HomiziSpace.cardRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatRow(
                      label: 'Rent paid over ${result.years} years',
                      value: formatInr(result.totalRentPaidInr),
                      valueKey: 'smart-move-paid',
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      label: 'Illustrative return at 70%',
                      value: formatInr(result.estimatedReturnInr),
                      valueKey: 'smart-move-return',
                      emphasize: true,
                    ),
                    const SizedBox(height: 10),
                    _StatRow(
                      label: 'Still depreciated (about 30%)',
                      value: formatInr(result.depreciatedInr),
                      valueKey: 'smart-move-lost',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      homiziText(
                        context,
                        'Ordinary rent is usually 100% lost. This sketch keeps '
                        'about 70% countable if you move within Homizi’s concept '
                        'for flats around ₹${smartMoveFlatMinLakh}L–₹${smartMoveFlatMaxLakh}L.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HomiziColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text(
            homiziText(context, "I'm interested"),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            homiziText(
              context,
              'Leave a demo interest note. Nothing is charged and no outside service is called.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HomiziColors.inkSoft,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('smart-move-name'),
            controller: _name,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Your name'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownMenu<String>(
            key: const Key('smart-move-city'),
            initialSelection: _city,
            label: Text(homiziText(context, 'City')),
            dropdownMenuEntries: [
              for (final city in smartMoveCities)
                DropdownMenuEntry(value: city, label: city),
            ],
            onSelected: (String? value) {
              if (value != null) {
                setState(() => _city = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('smart-move-contact'),
            controller: _contact,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Phone or email'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('smart-move-notes'),
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Notes, optional'),
            ),
          ),
          if (_formNote != null) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, _formNote!),
              key: const Key('smart-move-form-note'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: HomiziColors.error,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('smart-move-interest'),
            onPressed: _busy ? null : _submitInterest,
            child: Text(homiziText(context, "I'm interested")),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.valueKey,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final String valueKey;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            homiziText(context, label),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HomiziColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          key: Key(valueKey),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: emphasize ? HomiziColors.accent : HomiziColors.ink,
          ),
        ),
      ],
    );
  }
}
