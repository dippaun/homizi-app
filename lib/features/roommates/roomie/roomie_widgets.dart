import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';
import 'package:homizi/features/shell/min_touch.dart';

class RoomiePage extends StatelessWidget {
  const RoomiePage({
    required this.title,
    required this.body,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return MinTouchScope(
      child: Scaffold(
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, title)),
          actions: actions,
        ),
        body: body,
      ),
    );
  }
}

class RoomieAvatar extends StatelessWidget {
  const RoomieAvatar({required this.name, this.radius = 24, super.key});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: HomiziColors.accent,
      child: Text(
        roomieInitials(name),
        style: TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }
}

class RoomieChip extends StatelessWidget {
  const RoomieChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(homiziText(context, label)),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: HomiziColors.accent,
      backgroundColor: HomiziColors.white,
      checkmarkColor: HomiziColors.ink,
      labelStyle: const TextStyle(color: HomiziColors.ink),
      side: BorderSide(
        color: selected ? HomiziColors.accent : HomiziColors.ink,
      ),
    );
  }
}

class RoomieSectionLabel extends StatelessWidget {
  const RoomieSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        homiziText(context, text),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class RoomiePercent extends StatelessWidget {
  const RoomiePercent({required this.percent, super.key});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: HomiziColors.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$percent%',
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class RoomieBreakdown extends StatelessWidget {
  const RoomieBreakdown({required this.fit, super.key});

  final RoomieFit fit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(
          context,
          'Budget',
          fit.budgetDetail,
          fit.budgetPoints,
          RoomieFit.budgetMax,
        ),
        _row(
          context,
          'Locality',
          fit.localityDetail,
          fit.localityPoints,
          RoomieFit.localityMax,
        ),
        _row(
          context,
          'Move-in',
          fit.moveInDetail,
          fit.moveInPoints,
          RoomieFit.moveInMax,
        ),
        _row(
          context,
          'Lifestyle',
          fit.lifestyleDetail,
          fit.lifestylePoints,
          RoomieFit.lifestyleMax,
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String detail,
    int points,
    int max,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  homiziText(context, label),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$points / $max',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: HomiziColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            homiziText(context, detail),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: HomiziColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

String roomieBudgetLine(RoomieFit fit) {
  final overlap = fit.overlap;
  if (overlap == null) {
    return 'No budget overlap';
  }
  return '${roomieMoneySpan(overlap)} overlap';
}

String roomieLocalityLine(RoomieFit fit) {
  if (fit.sharedLocalities.isEmpty) {
    return 'No shared locality';
  }
  return fit.sharedLocalities.join(', ');
}

String roomieRentLabel(int rent) => '${formatInr(rent)} / month';
