import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';

RentingCost rentingCostForListing(Listing listing) {
  return RentingCost(
    rent: listing.rentInr,
    deposit: listing.depositInr,
    brokerage: listing.brokerageInr,
    oneTime: 0,
    maintenance: listing.maintenanceInr,
    electricity: 0,
    water: 0,
    wifi: 0,
    otherMonthly: 0,
  );
}

/// Move-in total and monthly total, with each declared charge.
class RentCostBreakdown extends StatelessWidget {
  const RentCostBreakdown({
    required this.cost,
    this.detailed = false,
    super.key,
  });

  final RentingCost cost;

  /// Shows zero lines as well, so a wizard listing lists every charge.
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final lines = <(String, int)>[
      ('Monthly rent', cost.rent),
      ('Security deposit', cost.deposit),
      ('Brokerage', cost.brokerage),
      ('One-time charges', cost.oneTime),
      ('Maintenance', cost.maintenance),
      ('Electricity', cost.electricity),
      ('Water', cost.water),
      ('Wi-Fi', cost.wifi),
      ('Other monthly', cost.otherMonthly),
    ];
    final shown = [
      for (final line in lines)
        if (detailed || line.$2 > 0) line,
    ];
    final theme = Theme.of(context);
    return Container(
      key: const Key('listing-cost-breakdown'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, 'Cost of renting'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            homiziText(
              context,
              'Declared by the host. A verified badge is a separate check.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: HomiziColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          for (final line in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(homiziText(context, line.$1))),
                  Text(homiziText(context, formatInr(line.$2))),
                ],
              ),
            ),
          const Divider(),
          _total(
            context,
            label: 'Move-in total',
            amount: cost.moveInTotal,
            totalKey: 'listing-cost-move-in',
          ),
          const SizedBox(height: 6),
          _total(
            context,
            label: 'Monthly total',
            amount: cost.monthlyTotal,
            totalKey: 'listing-cost-monthly',
          ),
        ],
      ),
    );
  }

  Widget _total(
    BuildContext context, {
    required String label,
    required int amount,
    required String totalKey,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            homiziText(context, label),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          homiziText(context, formatInr(amount)),
          key: Key(totalKey),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
