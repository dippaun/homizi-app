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
    this.showIntro = true,
    this.live = false,
    super.key,
  });

  final RentingCost cost;

  /// Shows zero lines as well, so a wizard listing lists every charge.
  final bool detailed;

  /// The detail page already titles the collapsible section.
  final bool showIntro;

  /// Count-up numbers, a pulsing "Calculating live" mark, and a border
  /// sweep whenever a charge changes. Used on the listing form.
  final bool live;

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
    final body = Container(
      key: const Key('listing-cost-breakdown'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIntro) ...[
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
          ],
          if (live) ...[const _CalculatingLive(), const SizedBox(height: 10)],
          for (final line in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(homiziText(context, line.$1))),
                  _amount(context, line.$2, 'listing-cost-${line.$1}'),
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
    if (!live) {
      return body;
    }
    return _SweepBorder(
      token: cost.moveInTotal + cost.monthlyTotal,
      child: body,
    );
  }

  Widget _amount(BuildContext context, int amount, String amountKey) {
    final style = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: HomiziColors.ink);
    if (!live) {
      return Text(homiziText(context, formatInr(amount)));
    }
    return AnimatedInr(amount: amount, style: style, valueKey: Key(amountKey));
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
        live
            ? AnimatedInr(
                amount: amount,
                valueKey: Key(totalKey),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Text(
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

/// Counts from the previous amount to the next one.
class AnimatedInr extends StatefulWidget {
  const AnimatedInr({
    required this.amount,
    required this.valueKey,
    this.style,
    super.key,
  });

  final int amount;
  final Key valueKey;
  final TextStyle? style;

  @override
  State<AnimatedInr> createState() => _AnimatedInrState();
}

class _AnimatedInrState extends State<AnimatedInr>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _from = 0;

  @override
  void initState() {
    super.initState();
    _from = widget.amount;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void didUpdateWidget(AnimatedInr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount == widget.amount) {
      return;
    }
    _from = oldWidget.amount;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(
          _controller.isAnimating ? _controller.value : 1,
        );
        final shown = _controller.isAnimating
            ? (_from + (widget.amount - _from) * t).round()
            : widget.amount;
        return Text(
          homiziText(context, formatInr(shown)),
          key: widget.valueKey,
          style: widget.style,
        );
      },
    );
  }
}

class _CalculatingLive extends StatefulWidget {
  const _CalculatingLive();

  @override
  State<_CalculatingLive> createState() => _CalculatingLiveState();
}

class _CalculatingLiveState extends State<_CalculatingLive>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _pulse.forward().then((_) {
      if (mounted) {
        _pulse.reverse();
      }
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('listing-cost-live'),
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1).animate(_pulse),
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [HomiziColors.brandGolden, HomiziColors.logoOrange],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          homiziText(context, 'Calculating live'),
          style: const TextStyle(
            color: HomiziColors.inkSoft,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SweepBorder extends StatefulWidget {
  const _SweepBorder({required this.token, required this.child});

  final int token;
  final Widget child;

  @override
  State<_SweepBorder> createState() => _SweepBorderState();
}

class _SweepBorderState extends State<_SweepBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep;
  int? _seen;

  @override
  void initState() {
    super.initState();
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _seen = widget.token;
  }

  @override
  void didUpdateWidget(_SweepBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.token != _seen) {
      _seen = widget.token;
      _sweep.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sweep,
      builder: (context, child) {
        final t = _sweep.value;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment(-1.4 + (t * 2.8), -1),
              end: Alignment(-0.2 + (t * 2.8), 1),
              colors: const [
                HomiziColors.line,
                HomiziColors.brandGolden,
                HomiziColors.logoOrange,
                HomiziColors.line,
              ],
            ),
          ),
          child: Padding(padding: const EdgeInsets.all(1.5), child: child),
        );
      },
      child: widget.child,
    );
  }
}
