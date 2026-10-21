import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/features/roommates/roomie/priority_match.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/roommates/roomie/roomie_widgets.dart';

const _locationChoices = <String>[
  'Bandra',
  'Khar',
  'Santacruz',
  'Andheri West',
  'Bandra West',
  'Powai',
  'Juhu',
  'Dadar',
];

class RoomiePrioritiesScreen extends ConsumerStatefulWidget {
  const RoomiePrioritiesScreen({super.key});

  @override
  ConsumerState<RoomiePrioritiesScreen> createState() =>
      _RoomiePrioritiesScreenState();
}

class _RoomiePrioritiesScreenState
    extends ConsumerState<RoomiePrioritiesScreen> {
  var _savedNote = false;

  @override
  Widget build(BuildContext context) {
    final priorities = ref.watch(searchPrioritiesProvider);
    final brief = ref.watch(roomieProvider).brief;
    final lifestyle = lifestylePriorityLabel(
      smoking: brief?.smoking ?? 'no',
      drinking: brief?.drinking ?? 'no',
    );
    final theme = Theme.of(context);
    final ordered = priorities.ordered;
    return RoomiePage(
      title: 'Set Your Priorities',
      body: ReorderableListView(
        key: const Key('roomie-priorities-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        buildDefaultDragHandles: false,
        onReorderItem: (oldIndex, newIndex) {
          ref
              .read(searchPrioritiesProvider.notifier)
              .reorder(oldIndex, newIndex);
        },
        header: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              key: const Key('roomie-priorities-banner'),
              color: HomiziColors.accentWash,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: HomiziColors.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      homiziText(
                        context,
                        'Rank what is most important to you. 1 = Highest priority, 8 = Lowest priority',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('roomie-priorities-save'),
                onPressed: () {
                  ref.read(searchPrioritiesProvider.notifier).save();
                  setState(() => _savedNote = true);
                },
                child: Text(homiziText(context, 'Save Priorities')),
              ),
            ),
            if (_savedNote) ...[
              const SizedBox(height: 12),
              Text(
                homiziText(context, 'Priorities saved'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ],
        ),
        children: [
          for (var index = 0; index < ordered.length; index++)
            _PriorityRow(
              key: ValueKey(ordered[index]),
              index: index,
              criterion: ordered[index],
              priorities: priorities,
              lifestyleLabel: lifestyle,
              onRank: (rank) {
                ref
                    .read(searchPrioritiesProvider.notifier)
                    .setRank(ordered[index], rank);
              },
              onEdit: () => unawaited(_edit(ordered[index], priorities)),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(
    PriorityCriterion criterion,
    SearchPriorities priorities,
  ) async {
    if (criterion == PriorityCriterion.lifestyle) {
      await context.push(RoutePaths.roomieLifestyle);
      return;
    }
    final next = await showDialog<SearchPriorities>(
      context: context,
      builder: (context) =>
          _PriorityEditor(criterion: criterion, priorities: priorities),
    );
    if (next == null) {
      return;
    }
    ref.read(searchPrioritiesProvider.notifier).replace(next);
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({
    required super.key,
    required this.index,
    required this.criterion,
    required this.priorities,
    required this.lifestyleLabel,
    required this.onRank,
    required this.onEdit,
  });

  final int index;
  final PriorityCriterion criterion;
  final SearchPriorities priorities;
  final String lifestyleLabel;
  final ValueChanged<int> onRank;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rank = priorities.rankOf(criterion);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: HomiziColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: HomiziColors.muted),
              ),
              const SizedBox(width: 4),
              Icon(_icon(criterion), color: HomiziColors.accent),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  key: Key('priority-row-${criterion.name}'),
                  onTap: onEdit,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, priorityTitle(criterion)),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        homiziText(
                          context,
                          prioritySubtitle(
                            priorities,
                            criterion,
                            lifestyleLabel: lifestyleLabel,
                          ),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: HomiziColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<int>(
                key: Key('priority-rank-${criterion.name}'),
                initialValue: rank,
                onSelected: onRank,
                itemBuilder: (context) {
                  return [
                    for (var value = 1; value <= 8; value++)
                      PopupMenuItem(
                        value: value,
                        child: Text(homiziText(context, 'Priority $value')),
                      ),
                  ];
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: HomiziColors.mist,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        homiziText(context, 'Priority $rank'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: HomiziColors.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _icon(PriorityCriterion criterion) => switch (criterion) {
  PriorityCriterion.budget => Icons.currency_rupee,
  PriorityCriterion.occupancy => Icons.person_outline,
  PriorityCriterion.location => Icons.location_on_outlined,
  PriorityCriterion.moveIn => Icons.calendar_today_outlined,
  PriorityCriterion.gender => Icons.groups_outlined,
  PriorityCriterion.propertyType => Icons.apartment,
  PriorityCriterion.lifestyle => Icons.favorite_outline,
  PriorityCriterion.furnishing => Icons.chair_outlined,
};

class _PriorityEditor extends StatefulWidget {
  const _PriorityEditor({required this.criterion, required this.priorities});

  final PriorityCriterion criterion;
  final SearchPriorities priorities;

  @override
  State<_PriorityEditor> createState() => _PriorityEditorState();
}

class _PriorityEditorState extends State<_PriorityEditor> {
  late int _budgetMin = widget.priorities.budgetMinInr;
  late int _budgetMax = widget.priorities.budgetMaxInr;
  late String _occupancy = widget.priorities.occupancy;
  late final List<String> _locations = [...widget.priorities.locations];
  late DateTime _moveIn = widget.priorities.moveIn;
  late String _gender = widget.priorities.gender;
  late final List<String> _types = [...widget.priorities.propertyTypes];
  late String _furnishing = widget.priorities.furnishing;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: HomiziColors.white,
      title: Text(homiziText(context, priorityTitle(widget.criterion))),
      content: SizedBox(width: 420, child: _body()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(homiziText(context, 'Cancel')),
        ),
        FilledButton(
          key: const Key('priority-editor-save'),
          onPressed: () => Navigator.pop(context, _next()),
          child: Text(homiziText(context, 'Save')),
        ),
      ],
    );
  }

  Widget _body() {
    return switch (widget.criterion) {
      PriorityCriterion.budget => HomiziRangeField(
        label: 'Budget',
        min: InrRangeScale.min,
        max: InrRangeScale.max,
        step: InrRangeScale.step,
        start: _budgetMin,
        end: _budgetMax,
        formatValue: formatInr,
        minSemantics: 'Minimum budget',
        maxSemantics: 'Maximum budget',
        onChanged: (start, end) {
          setState(() {
            _budgetMin = start;
            _budgetMax = end;
          });
        },
      ),
      PriorityCriterion.occupancy => _picks(
        const ['single', 'shared', 'any'],
        _occupancy,
        const {'single': 'Single', 'shared': 'Shared', 'any': 'Any'},
        (value) => setState(() => _occupancy = value),
      ),
      PriorityCriterion.location => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final name in _locationChoices)
            FilterChip(
              label: Text(homiziText(context, name)),
              selected: _locations.contains(name),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _locations.add(name);
                  } else {
                    _locations.remove(name);
                  }
                });
              },
            ),
        ],
      ),
      PriorityCriterion.moveIn => Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          onPressed: _pickDate,
          child: Text(homiziText(context, roomieDayLabel(_moveIn))),
        ),
      ),
      PriorityCriterion.gender => _picks(
        const ['any', 'women', 'men', 'same'],
        _gender,
        const {
          'any': 'Any',
          'women': 'Women',
          'men': 'Men',
          'same': 'Same as me',
        },
        (value) => setState(() => _gender = value),
      ),
      PriorityCriterion.propertyType => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in const {
            'flat': 'Flat',
            'pg': 'PG',
            'shared_room': 'Shared Room',
          }.entries)
            FilterChip(
              label: Text(homiziText(context, entry.value)),
              selected: _types.contains(entry.key),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _types.add(entry.key);
                  } else {
                    _types.remove(entry.key);
                  }
                });
              },
            ),
        ],
      ),
      PriorityCriterion.lifestyle => const SizedBox.shrink(),
      PriorityCriterion.furnishing => _picks(
        const ['furnished', 'semi_furnished', 'unfurnished'],
        _furnishing,
        const {
          'furnished': 'Furnished',
          'semi_furnished': 'Semi-furnished',
          'unfurnished': 'Unfurnished',
        },
        (value) => setState(() => _furnishing = value),
      ),
    };
  }

  Widget _picks(
    List<String> values,
    String selected,
    Map<String, String> labels,
    ValueChanged<String> onSelected,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          ChoiceChip(
            label: Text(homiziText(context, labels[value] ?? value)),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final initial = _moveIn.isBefore(first) ? first : _moveIn;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: first.add(const Duration(days: 730)),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _moveIn = DateTime.utc(picked.year, picked.month, picked.day);
    });
  }

  SearchPriorities _next() {
    final places = _locations.isEmpty
        ? widget.priorities.locations
        : List<String>.from(_locations);
    final types = _types.isEmpty
        ? widget.priorities.propertyTypes
        : List<String>.from(_types);
    return widget.priorities.copyWith(
      budgetMinInr: _budgetMin,
      budgetMaxInr: _budgetMax,
      occupancy: _occupancy,
      locations: places,
      moveInYear: _moveIn.year,
      moveInMonth: _moveIn.month,
      moveInDay: _moveIn.day,
      gender: _gender,
      propertyTypes: types,
      furnishing: _furnishing,
    );
  }
}
