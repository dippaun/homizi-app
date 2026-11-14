import 'dart:async';

import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';

int liveMoney(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return 0;
  }
  final value = int.tryParse(text);
  if (value == null || value < 0) {
    return 0;
  }
  return value;
}

RentingCost rentingCostFromFields({
  required String rent,
  required String deposit,
  required String brokerage,
  required String oneTime,
  required String maintenance,
  required String electricity,
  required String water,
  required String wifi,
  required String otherMonthly,
}) {
  return RentingCost(
    rent: liveMoney(rent),
    deposit: liveMoney(deposit),
    brokerage: liveMoney(brokerage),
    oneTime: liveMoney(oneTime),
    maintenance: liveMoney(maintenance),
    electricity: liveMoney(electricity),
    water: liveMoney(water),
    wifi: liveMoney(wifi),
    otherMonthly: liveMoney(otherMonthly),
  );
}

/// Cost of renting that follows the money fields on every keystroke.
///
/// A shimmering orange-to-purple border and a sparkle run while the numbers
/// change. Each amount counts up. A Live dot stays beside the title.
class LiveRentCostCard extends StatefulWidget {
  const LiveRentCostCard({
    required this.rent,
    required this.deposit,
    required this.brokerage,
    required this.oneTime,
    required this.maintenance,
    required this.electricity,
    required this.water,
    required this.wifi,
    required this.other,
    super.key,
  });

  final TextEditingController rent;
  final TextEditingController deposit;
  final TextEditingController brokerage;
  final TextEditingController oneTime;
  final TextEditingController maintenance;
  final TextEditingController electricity;
  final TextEditingController water;
  final TextEditingController wifi;
  final TextEditingController other;

  @override
  State<LiveRentCostCard> createState() => _LiveRentCostCardState();
}

class _LiveRentCostCardState extends State<LiveRentCostCard>
    with TickerProviderStateMixin {
  late final AnimationController _shimmer;
  late final AnimationController _pulse;
  Timer? _settle;
  var _calculating = false;
  late RentingCost _cost;

  List<TextEditingController> get _fields => [
    widget.rent,
    widget.deposit,
    widget.brokerage,
    widget.oneTime,
    widget.maintenance,
    widget.electricity,
    widget.water,
    widget.wifi,
    widget.other,
  ];

  @override
  void initState() {
    super.initState();
    _cost = _read();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..value = 1;
    for (final field in _fields) {
      field.addListener(_onEdit);
    }
  }

  RentingCost _read() {
    return rentingCostFromFields(
      rent: widget.rent.text,
      deposit: widget.deposit.text,
      brokerage: widget.brokerage.text,
      oneTime: widget.oneTime.text,
      maintenance: widget.maintenance.text,
      electricity: widget.electricity.text,
      water: widget.water.text,
      wifi: widget.wifi.text,
      otherMonthly: widget.other.text,
    );
  }

  void _onEdit() {
    _settle?.cancel();
    if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }
    if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
    setState(() {
      _calculating = true;
      _cost = _read();
    });
    _settle = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) {
        return;
      }
      _shimmer.stop();
      _pulse.stop();
      _pulse.value = 1;
      setState(() => _calculating = false);
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    for (final field in _fields) {
      field.removeListener(_onEdit);
    }
    _shimmer.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = <(String, int, String)>[
      ('Monthly rent', _cost.rent, 'listing-cost-rent'),
      ('Security deposit', _cost.deposit, 'listing-cost-deposit'),
      ('Brokerage', _cost.brokerage, 'listing-cost-brokerage'),
      ('One-time charges', _cost.oneTime, 'listing-cost-onetime'),
      ('Maintenance', _cost.maintenance, 'listing-cost-maintenance'),
      ('Electricity', _cost.electricity, 'listing-cost-electricity'),
      ('Water', _cost.water, 'listing-cost-water'),
      ('Wi-Fi', _cost.wifi, 'listing-cost-wifi'),
      ('Other monthly', _cost.otherMonthly, 'listing-cost-other'),
    ];
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, child) {
        final shift = _shimmer.value;
        return Container(
          key: const Key('listing-cost-breakdown'),
          padding: EdgeInsets.all(_calculating ? 2 : 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: _calculating
                ? LinearGradient(
                    begin: Alignment(-1 + shift * 2, -1),
                    end: Alignment(1, 1 - shift),
                    colors: const [
                      HomiziColors.logoOrange,
                      HomiziColors.homiziPurple,
                      HomiziColors.logoOrange,
                    ],
                  )
                : null,
            border: _calculating ? null : Border.all(color: HomiziColors.line),
          ),
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: HomiziColors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    homiziText(context, 'Cost of renting'),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (_calculating) ...[
                  const Icon(
                    Icons.auto_awesome,
                    key: Key('rent-cost-sparkle'),
                    color: HomiziColors.homiziPurple,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    homiziText(context, 'AI is calculating'),
                    key: const Key('rent-cost-calculating'),
                    style: const TextStyle(
                      color: HomiziColors.homiziPurple,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                FadeTransition(
                  opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
                  child: Container(
                    key: const Key('rent-cost-live'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: HomiziColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  homiziText(context, 'Live'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        homiziText(context, line.$1),
                        style: const TextStyle(
                          color: HomiziColors.inkSoft,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    _CountUp(
                      amount: line.$2,
                      amountKey: Key(line.$3),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 12),
            _total('Move-in total', _cost.moveInTotal, 'listing-cost-move-in'),
            const SizedBox(height: 4),
            _total('Monthly total', _cost.monthlyTotal, 'listing-cost-monthly'),
          ],
        ),
      ),
    );
  }

  Widget _total(String label, int amount, String totalKey) {
    return Row(
      children: [
        Expanded(
          child: Text(
            homiziText(context, label),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
        _CountUp(
          amount: amount,
          amountKey: Key(totalKey),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _CountUp extends StatefulWidget {
  const _CountUp({
    required this.amount,
    required this.amountKey,
    required this.style,
  });

  final int amount;
  final Key amountKey;
  final TextStyle style;

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp> {
  double _from = 0;

  @override
  void didUpdateWidget(_CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amount != widget.amount) {
      _from = oldWidget.amount.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: _from, end: widget.amount.toDouble()),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            homiziText(context, formatInr(value.round())),
            key: widget.amountKey,
            style: widget.style,
          ),
        );
      },
    );
  }
}
