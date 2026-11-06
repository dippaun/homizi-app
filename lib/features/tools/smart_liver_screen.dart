import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/tools/domain/smart_liver.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';

/// Be a Smart Liver: rent affordability calculator for tenants.
class SmartLiverScreen extends ConsumerStatefulWidget {
  const SmartLiverScreen({super.key});

  @override
  ConsumerState<SmartLiverScreen> createState() => _SmartLiverScreenState();
}

class _SmartLiverScreenState extends ConsumerState<SmartLiverScreen> {
  final _income = TextEditingController(text: '60000');
  final _emis = TextEditingController();
  SmartLiverResult? _result;
  String? _note;

  @override
  void dispose() {
    _income.dispose();
    _emis.dispose();
    super.dispose();
  }

  void _calculate() {
    final income = wholeRupees(_income.text);
    final emisRaw = _emis.text.trim();
    final emis = emisRaw.isEmpty ? 0 : wholeRupees(emisRaw);
    if (income == null || income <= 0) {
      setState(() {
        _result = null;
        _note = 'Enter your monthly take-home income in whole rupees.';
      });
      return;
    }
    if (emis == null) {
      setState(() {
        _result = null;
        _note = 'Enter other EMIs in whole rupees, or leave them blank.';
      });
      return;
    }
    try {
      final result = smartLiver(
        SmartLiverInput(monthlyIncomeInr: income, otherEmisInr: emis),
      );
      setState(() {
        _result = result;
        _note = null;
      });
    } on ArgumentError catch (error) {
      setState(() {
        _result = null;
        _note = error.message?.toString() ?? 'Could not calculate.';
      });
    }
  }

  void _searchHomes(SmartLiverResult result) {
    ref
        .read(listingFilterProvider.notifier)
        .replace(
          ListingFilters(
            budgetMinInr: result.rentMinInr,
            budgetMaxInr: result.rentMaxInr,
          ),
        );
    context.go(RoutePaths.explore);
  }

  void _confirm(SmartLiverResult result) {
    openDemoSuccess(
      context,
      title: 'Smart Liver plan ready',
      detail:
          'Healthy rent ${formatInr(result.rentMinInr)}–${formatInr(result.rentMaxInr)}. '
          'No money moved. This is a tip, not advice.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      key: const Key('smart-liver-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Be a Smart Liver')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'See how much rent fits your income. HOMIZI does not collect rent or give financial advice.',
            ),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('smart-liver-income'),
            controller: _income,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Monthly take-home income (₹)'),
              hintText: '60000',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('smart-liver-emis'),
            controller: _emis,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Other EMIs, optional (₹)'),
              hintText: '8000',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('smart-liver-calculate'),
            onPressed: _calculate,
            child: Text(homiziText(context, 'Calculate healthy rent')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, _note!),
              key: const Key('smart-liver-note'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: HomiziColors.error),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 20),
            Card(
              key: const Key('smart-liver-result'),
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
                    Text(
                      homiziText(context, 'Healthy rent range'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatInr(result.rentMinInr)} – ${formatInr(result.rentMaxInr)}',
                      key: const Key('smart-liver-range'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: HomiziColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      homiziText(
                        context,
                        'About 25–30% of ${formatInr(result.monthlyIncomeInr)} take-home'
                        '${result.otherEmisInr > 0 ? ', after ${formatInr(result.otherEmisInr)} in other EMIs' : ''}.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: HomiziColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: HomiziColors.accentWash,
                        borderRadius: BorderRadius.circular(HomiziSpace.radius),
                      ),
                      child: Text(
                        homiziText(context, result.tip),
                        key: const Key('smart-liver-tip'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: HomiziColors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              key: const Key('smart-liver-search'),
              onPressed: () => _searchHomes(result),
              child: Text(homiziText(context, 'Search homes in this range')),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('smart-liver-done'),
              onPressed: () => _confirm(result),
              child: Text(homiziText(context, 'Save this tip')),
            ),
          ],
        ],
      ),
    );
  }
}
