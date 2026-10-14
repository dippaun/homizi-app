import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';

class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key});

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  late ListingFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(listingFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Filters'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          Text(
            homiziText(
              context,
              'Narrow the deck. Gender, religion, caste, and age are not filters.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          _ChoiceGroup(
            label: homiziText(context, 'City'),
            value: _draft.city,
            options: const {
              null: 'Any',
              'Bengaluru': 'Bengaluru',
              'Pune': 'Pune',
              'Hyderabad': 'Hyderabad',
              'Mumbai': 'Mumbai',
              'Delhi NCR': 'Delhi NCR',
            },
            onChanged: (value) => setState(() {
              _draft = value == null
                  ? _draft.copyWith(clearCity: true)
                  : _draft.copyWith(city: value);
            }),
          ),
          const SectionLabel('BHK'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            segments: [
              ButtonSegment<int>(
                value: 1,
                label: Text(homiziText(context, '1 BHK')),
              ),
              ButtonSegment<int>(
                value: 2,
                label: Text(homiziText(context, '2 BHK')),
              ),
              ButtonSegment<int>(
                value: 3,
                label: Text(homiziText(context, '3 BHK')),
              ),
            ],
            selected: _draft.bedrooms == null ? <int>{} : {_draft.bedrooms!},
            onSelectionChanged: (next) => setState(() {
              _draft = next.isEmpty
                  ? _draft.copyWith(clearBedrooms: true)
                  : _draft.copyWith(bedrooms: next.first);
            }),
          ),
          const SizedBox(height: 18),
          SectionLabel(
            _draft.budgetMaxInr == null
                ? 'Budget ceiling · Any'
                : 'Budget ceiling · ${formatInr(_draft.budgetMaxInr!)}',
          ),
          Slider(
            value: (_draft.budgetMaxInr ?? 60000)
                .clamp(10000, 60000)
                .toDouble(),
            min: 10000,
            max: 60000,
            divisions: 10,
            label: _draft.budgetMaxInr == null
                ? 'Any'
                : formatInr(_draft.budgetMaxInr!),
            onChanged: (value) => setState(() {
              _draft = value >= 60000
                  ? _draft.copyWith(clearBudget: true)
                  : _draft.copyWith(budgetMaxInr: value.round());
            }),
          ),
          const Divider(),
          _ChoiceGroup(
            label: homiziText(context, 'Furnishing'),
            value: _draft.furnishing,
            options: const {
              null: 'Any',
              'unfurnished': 'Unfurnished',
              'semi_furnished': 'Semi-furnished',
              'furnished': 'Furnished',
            },
            onChanged: (value) => setState(() {
              _draft = value == null
                  ? _draft.copyWith(clearFurnishing: true)
                  : _draft.copyWith(furnishing: value);
            }),
          ),
          _ChoiceGroup(
            label: homiziText(context, 'Property type'),
            value: _draft.propertyType,
            options: const {
              null: 'Any',
              'apartment': 'Apartment',
              'private_room': 'Private room',
              'shared_room': 'Shared room',
              'studio': 'Studio',
            },
            onChanged: (value) => setState(() {
              _draft = value == null
                  ? _draft.copyWith(clearPropertyType: true)
                  : _draft.copyWith(propertyType: value);
            }),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              ref.read(listingFilterProvider.notifier).replace(_draft);
              context.pop();
            },
            child: Text(homiziText(context, 'Show homes')),
          ),
          TextButton(
            onPressed: () => setState(() => _draft = const ListingFilters()),
            child: Text(homiziText(context, 'Reset')),
          ),
        ],
      ),
    );
  }
}

class _ChoiceGroup extends StatelessWidget {
  const _ChoiceGroup({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final Map<String?, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionLabel(label),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in options.entries)
                FilterChip(
                  label: Text(homiziText(context, entry.value)),
                  selected: entry.key == value,
                  onSelected: (_) => onChanged(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
