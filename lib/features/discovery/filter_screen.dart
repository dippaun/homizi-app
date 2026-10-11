import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      appBar: AppBar(title: const Text('Filters')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _ChoiceGroup(
            label: 'City',
            value: _draft.city,
            options: const {
              null: 'Any',
              'Bengaluru': 'Bengaluru',
              'Pune': 'Pune',
              'Hyderabad': 'Hyderabad',
              'Mumbai': 'Mumbai',
            },
            onChanged: (value) => setState(() {
              _draft = value == null
                  ? _draft.copyWith(clearCity: true)
                  : _draft.copyWith(city: value);
            }),
          ),
          _ChoiceGroup(
            label: 'Budget ceiling',
            value: _draft.budgetMaxInr?.toString(),
            options: const {
              null: 'Any',
              '15000': 'Up to ₹15,000',
              '25000': 'Up to ₹25,000',
              '40000': 'Up to ₹40,000',
            },
            onChanged: (value) => setState(() {
              _draft = value == null
                  ? _draft.copyWith(clearBudget: true)
                  : _draft.copyWith(budgetMaxInr: int.parse(value));
            }),
          ),
          _ChoiceGroup(
            label: 'Furnishing',
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
            label: 'Property type',
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
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ref.read(listingFilterProvider.notifier).replace(_draft);
              context.pop();
            },
            child: const Text('Show homes'),
          ),
          TextButton(
            onPressed: () => setState(() => _draft = const ListingFilters()),
            child: const Text('Reset'),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in options.entries)
                ChoiceChip(
                  label: Text(entry.value),
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
