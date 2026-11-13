import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';

String finderHeadline(int? percent) {
  if (percent == null) {
    return 'Score unavailable';
  }
  if (matchStrength(percent) == MatchStrength.strong && percent >= 85) {
    return 'Great Match!';
  }
  return matchStrengthLabel(matchStrength(percent));
}

class CompatibilityRing extends StatelessWidget {
  const CompatibilityRing({required this.percent, this.size = 72, super.key});

  final int? percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(percent: value),
        child: Center(
          child: Text(
            value == null ? '—' : '$value%',
            key: const Key('roommate-percent'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: value == null ? HomiziColors.muted : HomiziColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.percent});

  final int? percent;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final rect = Offset.zero & size;
    final deflated = rect.deflate(stroke);
    final track = Paint()
      ..color = HomiziColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(deflated, 0, 6.28318, false, track);
    final value = percent;
    if (value == null || value <= 0) {
      return;
    }
    final paint = Paint()
      ..color = HomiziColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      deflated,
      -1.5708,
      6.28318 * (value.clamp(0, 100) / 100),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.percent != percent;
  }
}

class RoommateActionBar extends StatelessWidget {
  const RoommateActionBar({
    required this.onSkip,
    required this.onMaybe,
    required this.onInterested,
    this.interestedLabel = '',
    this.keyPrefix = 'roommate',
    super.key,
  });

  final VoidCallback onSkip;
  final VoidCallback onMaybe;
  final VoidCallback onInterested;
  final String interestedLabel;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundAction(
          actionKey: Key('$keyPrefix-skip'),
          tooltip: 'Skip',
          color: HomiziColors.white,
          border: HomiziColors.line,
          icon: Icons.close,
          iconColor: HomiziColors.error,
          label: interestedLabel.isEmpty ? null : 'Skip',
          onPressed: onSkip,
        ),
        _RoundAction(
          actionKey: Key('$keyPrefix-maybe'),
          tooltip: 'Maybe',
          color: HomiziColors.accentWash,
          border: HomiziColors.brandGolden,
          icon: Icons.star_rounded,
          iconColor: HomiziColors.ink,
          label: interestedLabel.isEmpty ? null : 'Maybe',
          onPressed: onMaybe,
        ),
        _RoundAction(
          actionKey: Key('$keyPrefix-interested'),
          tooltip: "I'm Interested",
          color: HomiziColors.logoOrange,
          border: HomiziColors.logoOrange,
          icon: Icons.favorite,
          iconColor: HomiziColors.ink,
          label: interestedLabel.isEmpty ? null : interestedLabel,
          onPressed: onInterested,
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.actionKey,
    required this.tooltip,
    required this.color,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    this.label,
  });

  final Key actionKey;
  final String tooltip;
  final Color color;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: HomiziColors.shadow,
      child: InkWell(
        key: actionKey,
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
    if (label == null) {
      return Tooltip(message: homiziText(context, tooltip), child: button);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(message: homiziText(context, tooltip), child: button),
        const SizedBox(height: 6),
        Text(
          homiziText(context, label!),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class RoommateStackCard extends StatelessWidget {
  const RoommateStackCard({
    required this.person,
    required this.index,
    required this.total,
    required this.onOpen,
    super.key,
  });

  final FinderPerson person;
  final int index;
  final int total;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = person.gallery.isEmpty
        ? person.seeker.photoRef
        : person.gallery.first;
    return Material(
      key: const Key('roommate-card'),
      color: HomiziColors.white,
      elevation: 6,
      shadowColor: HomiziColors.shadowStrong,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        key: Key('roommate-open-${person.id}'),
        borderRadius: BorderRadius.circular(28),
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: Stack(
                children: [
                  Hero(
                    tag: 'roommate-photo-${person.id}',
                    child: SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: photo == null
                          ? const ColoredBox(color: HomiziColors.soft)
                          : Image.asset(photo, fit: BoxFit.cover),
                    ),
                  ),
                  if (person.seeker.trust.anyIdentity)
                    const Positioned(left: 12, top: 12, child: _VerifiedChip()),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: _CountChip(label: '${index + 1}/$total'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${person.seeker.age} · ${person.group}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HomiziColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      _Meta(
                        icon: Icons.currency_rupee,
                        text: person.seeker.budgetLabel,
                      ),
                      _Meta(
                        icon: Icons.person_outline,
                        text: finderGenderLabel(person.traits.gender),
                      ),
                      _Meta(
                        icon: Icons.apartment_outlined,
                        text: person.lookingFor,
                      ),
                      _Meta(
                        icon: Icons.calendar_today_outlined,
                        text: finderMoveInLabel(person.traits.moveIn),
                      ),
                      _Meta(
                        icon: Icons.place_outlined,
                        text: person.traits.city,
                      ),
                      _Meta(icon: Icons.work_outline, text: person.field),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final chip in finderLifestyleChips(person))
                        _SoftChip(label: chip),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '“${person.seeker.traits.thoughts}”',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HomiziColors.inkSoft,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedChip extends StatelessWidget {
  const _VerifiedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('roommate-verified'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HomiziColors.success,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 14, color: HomiziColors.onSuccess),
          const SizedBox(width: 4),
          Text(
            homiziText(context, 'Verified'),
            style: const TextStyle(
              color: HomiziColors.onSuccess,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('roommate-counter'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HomiziColors.ink.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: HomiziColors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: HomiziColors.muted),
        const SizedBox(width: 2),
        Text(
          text,
          style: const TextStyle(
            color: HomiziColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: HomiziColors.success,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class RoommateFilterSheet extends StatefulWidget {
  const RoommateFilterSheet({required this.initial, super.key});

  final FinderFilters initial;

  @override
  State<RoommateFilterSheet> createState() => _RoommateFilterSheetState();
}

class _RoommateFilterSheetState extends State<RoommateFilterSheet> {
  late FinderFilters _draft;
  late final TextEditingController _locality;
  var _more = false;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _locality = TextEditingController(text: widget.initial.locality);
  }

  @override
  void dispose() {
    _locality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: RepaintBoundary(
        key: const Key('roommate-filter-shot'),
        child: Material(
          key: const Key('roommate-filter-sheet'),
          color: HomiziColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HomiziColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                homiziText(context, 'Filter Roommates'),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                homiziText(context, 'Gender'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'any', label: Text('Any')),
                  ButtonSegment(value: 'man', label: Text('Male')),
                  ButtonSegment(value: 'woman', label: Text('Female')),
                ],
                selected: {_draft.gender},
                onSelectionChanged: (value) {
                  setState(() => _draft = _draft.copyWith(gender: value.first));
                },
              ),
              const SizedBox(height: 16),
              Text(
                homiziText(context, 'Budget (per person)'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: HomiziColors.ink,
                ),
              ),
              Text(
                '${formatInr(_draft.budgetMin)} – ${formatInr(_draft.budgetMax)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: HomiziColors.inkSoft,
                ),
              ),
              RangeSlider(
                key: const Key('roommate-budget'),
                min: 5000,
                max: 30000,
                divisions: 25,
                values: RangeValues(
                  _draft.budgetMin.toDouble().clamp(5000, 30000),
                  _draft.budgetMax.toDouble().clamp(5000, 30000),
                ),
                activeColor: HomiziColors.logoOrange,
                labels: RangeLabels(
                  formatInr(_draft.budgetMin),
                  formatInr(_draft.budgetMax),
                ),
                onChanged: (value) {
                  setState(() {
                    _draft = _draft.copyWith(
                      budgetMin: value.start.round(),
                      budgetMax: value.end.round(),
                    );
                  });
                },
              ),
              Text(
                homiziText(context, 'Occupation'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: HomiziColors.ink,
                ),
              ),
              for (final group in const [
                'Working Professional',
                'Student',
                'Freelancer',
                'Other',
              ])
                CheckboxListTile(
                  key: Key('roommate-group-$group'),
                  contentPadding: EdgeInsets.zero,
                  value: _draft.groups.contains(group),
                  activeColor: HomiziColors.logoOrange,
                  title: Text(
                    homiziText(context, group),
                    style: const TextStyle(color: HomiziColors.ink),
                  ),
                  onChanged: (checked) {
                    final next = {..._draft.groups};
                    if (checked ?? false) {
                      next.add(group);
                    } else {
                      next.remove(group);
                    }
                    setState(() => _draft = _draft.copyWith(groups: next));
                  },
                ),
              Text(
                homiziText(context, 'Lifestyle'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: HomiziColors.ink,
                ),
              ),
              _life(
                'Non-Smoker',
                Icons.smoke_free,
                _draft.nonSmoker,
                (value) => _draft = _draft.copyWith(nonSmoker: value),
              ),
              _life(
                'Occasional Drinking',
                Icons.local_bar_outlined,
                _draft.occasionalDrinking,
                (value) => _draft = _draft.copyWith(occasionalDrinking: value),
              ),
              _life(
                'Vegetarian',
                Icons.eco_outlined,
                _draft.vegetarian,
                (value) => _draft = _draft.copyWith(vegetarian: value),
              ),
              _life(
                'Pet Friendly',
                Icons.pets,
                _draft.petFriendly,
                (value) => _draft = _draft.copyWith(petFriendly: value),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('roommate-more-filters'),
                  onPressed: () => setState(() => _more = !_more),
                  icon: Icon(
                    _more ? Icons.expand_less : Icons.expand_more,
                    color: HomiziColors.ink,
                  ),
                  label: Text(
                    homiziText(context, 'More Filters'),
                    style: const TextStyle(color: HomiziColors.ink),
                  ),
                ),
              ),
              if (_more) ...[
                _choice(
                  'Smoking',
                  _draft.smoking,
                  const {
                    'any': 'Any',
                    'never': 'Non-smoker',
                    'sometimes': 'Occasionally',
                    'regularly': 'Regularly',
                  },
                  (value) => _draft = _draft.copyWith(smoking: value),
                ),
                _choice(
                  'Drinking',
                  _draft.drinking,
                  const {
                    'any': 'Any',
                    'no': 'No',
                    'occasional': 'Occasional',
                    'yes': 'Yes',
                  },
                  (value) => _draft = _draft.copyWith(drinking: value),
                ),
                _choice(
                  'Veg / Non-veg',
                  _draft.diet,
                  const {'any': 'Any', 'veg': 'Veg', 'non_veg': 'Non-veg'},
                  (value) => _draft = _draft.copyWith(diet: value),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('roommate-preferred-location'),
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'Preferred location'),
                    hintText: homiziText(context, 'Satellite, Bodakdev'),
                  ),
                  controller: _locality,
                  onChanged: (value) =>
                      _draft = _draft.copyWith(locality: value),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    homiziText(context, 'Move-in date'),
                    style: const TextStyle(color: HomiziColors.ink),
                  ),
                  subtitle: Text(
                    _draft.moveIn == null
                        ? homiziText(context, 'Any date')
                        : finderMoveInLabel(_draft.moveIn),
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                  trailing: const Icon(Icons.event, color: HomiziColors.ink),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _draft.moveIn ?? DateTime.utc(2026, 11, 30),
                      firstDate: DateTime.utc(2026),
                      lastDate: DateTime.utc(2027, 12, 31),
                    );
                    if (picked == null) {
                      return;
                    }
                    setState(() {
                      _draft = _draft.copyWith(
                        moveIn: DateTime.utc(
                          picked.year,
                          picked.month,
                          picked.day,
                        ),
                      );
                    });
                  },
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('roommate-apply-filters'),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.logoOrange,
                  foregroundColor: HomiziColors.ink,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.pop(context, _draft),
                child: Text(homiziText(context, 'Apply Filters')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _life(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return CheckboxListTile(
      key: Key('roommate-life-$label'),
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: HomiziColors.success),
      value: value,
      activeColor: HomiziColors.logoOrange,
      title: Text(label, style: const TextStyle(color: HomiziColors.ink)),
      onChanged: (checked) => setState(() => onChanged(checked ?? false)),
    );
  }

  Widget _choice(
    String label,
    String selected,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final entry in options.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: selected == entry.key,
                  onSelected: (_) => setState(() => onChanged(entry.key)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
