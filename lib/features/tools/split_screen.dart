import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/tools/domain/rent_split.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _ShareField {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  void dispose() {
    nameController.dispose();
    weightController.dispose();
  }
}

class _SplitScreenState extends State<SplitScreen> {
  final _rent = TextEditingController(text: '45000');
  final _deposit = TextEditingController(text: '150000');
  final _maintenance = TextEditingController(text: '3500');
  final _utilities = TextEditingController(text: '2200');
  final _income = TextEditingController(text: '120000');
  final _shares = <_ShareField>[];
  SplitResult? _result;
  String? _note;

  @override
  void initState() {
    super.initState();
    _add('Ananya Iyer', '2');
    _add('Rohan Mehta', '1');
  }

  void _add(String name, String weight) {
    final field = _ShareField();
    field.nameController.text = name;
    field.weightController.text = weight;
    _shares.add(field);
  }

  @override
  void dispose() {
    _rent.dispose();
    _deposit.dispose();
    _maintenance.dispose();
    _utilities.dispose();
    _income.dispose();
    for (final share in _shares) {
      share.dispose();
    }
    super.dispose();
  }

  void _calculate() {
    if (demoModeHere(context)) {
      openDemoSuccess(
        context,
        title: 'Split saved',
        detail: 'The room split stays on this device for the demo.',
      );
      return;
    }
    final rent = wholeRupees(_rent.text);
    final deposit = wholeRupees(_deposit.text);
    final maintenance = wholeRupees(_maintenance.text);
    final utilities = wholeRupees(_utilities.text);
    final incomeRaw = _income.text.trim();
    final income = incomeRaw.isEmpty ? null : wholeRupees(incomeRaw);
    if (rent == null ||
        deposit == null ||
        maintenance == null ||
        utilities == null ||
        (incomeRaw.isNotEmpty && income == null)) {
      setState(() {
        _note = 'Enter whole rupees for each amount.';
        _result = null;
      });
      return;
    }
    final shares = <FlatmateShare>[];
    for (final field in _shares) {
      final weight = int.tryParse(field.weightController.text.trim());
      if (weight == null || weight < 1) {
        setState(() {
          _note = 'Each room share must be at least 1.';
          _result = null;
        });
        return;
      }
      shares.add(
        FlatmateShare(name: field.nameController.text.trim(), weight: weight),
      );
    }
    try {
      final result = rentSplit(
        SplitInput(
          rentInr: rent,
          depositInr: deposit,
          maintenanceInr: maintenance,
          utilitiesInr: utilities,
          shares: shares,
          incomeInr: income,
        ),
      );
      setState(() {
        _result = result;
        _note = null;
      });
    } on ArgumentError catch (error) {
      setState(() {
        _result = null;
        _note =
            error.message?.toString() ?? 'The split could not be calculated.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Rent split')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'A larger room can take a higher weight. The shares add back to the amounts you enter.',
            ),
          ),
          const SizedBox(height: 16),
          _money(_rent, 'Rent', 'split-rent'),
          _money(_deposit, 'Deposit', 'split-deposit'),
          _money(_maintenance, 'Maintenance', 'split-maintenance'),
          _money(_utilities, 'Utilities', 'split-utilities'),
          _money(_income, 'Household take-home, optional', 'split-income'),
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Flatmates'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (var index = 0; index < _shares.length; index++) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: Key('split-name-$index'),
                    controller: _shares[index].nameController,
                    decoration: InputDecoration(
                      labelText: homiziText(context, 'Name'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    key: Key('split-weight-$index'),
                    controller: _shares[index].weightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: homiziText(context, 'Weight'),
                    ),
                  ),
                ),
              ],
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('split-add'),
              onPressed: () => setState(() => _add('', '1')),
              child: Text(homiziText(context, 'Add flatmate')),
            ),
          ),
          FilledButton(
            key: const Key('split-calculate'),
            onPressed: _calculate,
            child: Text(homiziText(context, 'Calculate')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(homiziText(context, _note!), key: const Key('split-note')),
          ],
          if (result != null) ...[
            const SizedBox(height: 16),
            Text(
              homiziText(
                context,
                'Monthly housing ${formatInr(result.monthlyPool)}',
              ),
              key: const Key('split-result'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (result.band != null)
              Text(
                homiziText(context, result.band!),
                key: const Key('split-band'),
              ),
            for (final line in result.lines)
              Card.filled(
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        line.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        homiziText(
                          context,
                          'Rent ${formatInr(line.rentInr)} · deposit ${formatInr(line.depositInr)}',
                        ),
                      ),
                      Text(
                        homiziText(
                          context,
                          'Maintenance ${formatInr(line.maintenanceInr)} · utilities ${formatInr(line.utilitiesInr)}',
                        ),
                      ),
                      Text(
                        homiziText(
                          context,
                          'Due each month ${formatInr(line.monthlyInr)}',
                        ),
                        key: Key('split-due-${line.name}'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _money(TextEditingController controller, String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key(key),
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: homiziText(context, label)),
      ),
    );
  }
}
