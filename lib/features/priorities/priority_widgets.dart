import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// One ranked row: P-badge, icon, title, value, Must have / Flexible chip
/// and the drag handle.
class PriorityRankRow extends StatelessWidget {
  const PriorityRankRow({
    required super.key,
    required this.wire,
    required this.index,
    required this.icon,
    required this.title,
    required this.value,
    required this.mustHave,
    required this.onToggleType,
    required this.onEdit,
    this.note,
  });

  final String wire;
  final int index;
  final IconData icon;
  final String title;
  final String value;
  final String? note;
  final bool mustHave;
  final VoidCallback onToggleType;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: HomiziColors.line),
        ),
        child: InkWell(
          key: Key('priority-row-$wire'),
          borderRadius: BorderRadius.circular(14),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 2, 10),
            child: Row(
              children: [
                PriorityBadge(
                  rank: index + 1,
                  badgeKey: Key('priority-rank-$wire'),
                ),
                const SizedBox(width: 10),
                Icon(icon, color: HomiziColors.logoOrange, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, title),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        homiziText(context, value),
                        key: Key('priority-value-$wire'),
                        style: const TextStyle(
                          color: HomiziColors.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (note != null)
                        Text(
                          homiziText(context, note!),
                          style: const TextStyle(
                            color: HomiziColors.muted,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                PriorityTypeChip(
                  chipKey: Key('priority-type-$wire'),
                  mustHave: mustHave,
                  onTap: onToggleType,
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_handle,
                      key: Key('priority-handle-$wire'),
                      color: HomiziColors.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({required this.rank, this.badgeKey, super.key});

  final int rank;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: badgeKey,
      width: 36,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [HomiziColors.logoOrange, HomiziColors.brandRedOrange],
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'P$rank',
        style: const TextStyle(
          color: HomiziColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Red "Must have" or green "Flexible". Tapping switches it.
class PriorityTypeChip extends StatelessWidget {
  const PriorityTypeChip({
    required this.mustHave,
    this.onTap,
    this.chipKey,
    super.key,
  });

  final bool mustHave;
  final VoidCallback? onTap;
  final Key? chipKey;

  @override
  Widget build(BuildContext context) {
    final label = mustHave ? 'Must have' : 'Flexible';
    return Semantics(
      button: onTap != null,
      label: homiziText(context, '$label. Tap to change.'),
      child: Material(
        color: mustHave ? HomiziColors.errorWash : HomiziColors.successWash,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: chipKey,
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              homiziText(context, label),
              style: TextStyle(
                color: mustHave ? HomiziColors.error : HomiziColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Choose your priority type": what Must have and Flexible mean.
class PriorityTypeExplainer extends StatelessWidget {
  const PriorityTypeExplainer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: Key('priority-type-explainer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _TypeCard(
            icon: Icons.gps_fixed,
            title: 'Must have',
            subtitle: 'Non-negotiable',
            lines: [
              'Deal-breaker needs',
              'A miss keeps a home out of the top band',
            ],
            mustHave: true,
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _TypeCard(
            icon: Icons.shuffle,
            title: 'Flexible',
            subtitle: 'Nice to have',
            lines: ['You are open to options', 'Helps you see more matches'],
            mustHave: false,
          ),
        ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.lines,
    required this.mustHave,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> lines;
  final bool mustHave;

  @override
  Widget build(BuildContext context) {
    final tone = mustHave ? HomiziColors.error : HomiziColors.success;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: mustHave ? HomiziColors.errorWash : HomiziColors.successWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 22),
          const SizedBox(height: 4),
          Text(
            homiziText(context, title),
            style: TextStyle(color: tone, fontWeight: FontWeight.w700),
          ),
          Text(
            homiziText(context, subtitle),
            style: const TextStyle(color: HomiziColors.inkSoft, fontSize: 12),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check, size: 14, color: tone),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      homiziText(context, line),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Small orange-on-white "Lifestyle" style segmented tabs.
class PriorityTabs extends StatelessWidget {
  const PriorityTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
    super.key,
  });

  final int index;
  final List<(String, IconData, String)> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: i == index ? null : HomiziColors.soft,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                decoration: i == index
                    ? BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            HomiziColors.logoOrange,
                            HomiziColors.brandRedOrange,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      )
                    : null,
                child: InkWell(
                  key: Key(labels[i].$3),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          labels[i].$2,
                          size: 18,
                          color: i == index
                              ? HomiziColors.white
                              : HomiziColors.success,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            homiziText(context, labels[i].$1),
                            style: TextStyle(
                              color: i == index
                                  ? HomiziColors.white
                                  : HomiziColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// The "How it works" strip from the board.
class PriorityHowItWorks extends StatelessWidget {
  const PriorityHowItWorks({required this.steps, super.key});

  final List<(IconData, String)> steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('how-it-works'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: HomiziColors.brandOrange.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [HomiziColors.logoOrange, HomiziColors.brandRedOrange],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              homiziText(context, 'How It Works'),
              style: const TextStyle(
                color: HomiziColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: HomiziColors.accentWash,
                    child: Icon(
                      steps[i].$1,
                      size: 16,
                      color: HomiziColors.logoOrange,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      homiziText(context, steps[i].$2),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (i < steps.length - 1)
                    const Icon(
                      Icons.arrow_downward,
                      size: 14,
                      color: HomiziColors.muted,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
