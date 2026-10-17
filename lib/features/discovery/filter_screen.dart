import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';
import 'package:homizi/features/discovery/feed_controller.dart';

class FilterScreen extends ConsumerStatefulWidget {
  const FilterScreen({super.key});

  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  late ListingFilters _draft;
  late final TextEditingController _locality;

  @override
  void initState() {
    super.initState();
    _draft = ref.read(listingFilterProvider);
    _locality = TextEditingController(text: _draft.locality ?? '');
  }

  @override
  void dispose() {
    _locality.dispose();
    super.dispose();
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
            options: {
              null: 'Any',
              for (final city in exploreCities) city: city,
            },
            onChanged: (value) => setState(() {
              _draft = value == null
                  ? _draft.copyWith(clearCity: true)
                  : _draft.copyWith(city: value);
            }),
          ),
          TextField(
            key: const Key('filter-locality'),
            controller: _locality,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Locality'),
              hintText: homiziText(context, 'Koramangala'),
            ),
            onChanged: (value) => setState(() {
              _draft = value.trim().isEmpty
                  ? _draft.copyWith(clearLocality: true)
                  : _draft.copyWith(locality: value.trim());
            }),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 8),
          HomiziRangeField(
            label: 'Rent',
            min: InrRangeScale.min,
            max: InrRangeScale.max,
            step: InrRangeScale.step,
            start: _draft.budgetMinInr ?? InrRangeScale.min,
            end: _draft.budgetMaxInr ?? InrRangeScale.max,
            formatValue: formatInr,
            openAtBounds: true,
            minSemantics: 'Minimum rent',
            maxSemantics: 'Maximum rent',
            sliderKey: const Key('filter-rent-slider'),
            valueKey: const Key('filter-rent-value'),
            onChanged: (start, end) => setState(() {
              final open = openBounds(
                start: start,
                end: end,
                min: InrRangeScale.min,
                max: InrRangeScale.max,
              );
              _draft = _draft.copyWith(
                budgetMinInr: open.start,
                budgetMaxInr: open.end,
                clearBudgetMin: open.start == null,
                clearBudget: open.end == null,
              );
            }),
          ),
          const SectionLabel('Budget band'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final band in budgetBands)
                FilterChip(
                  label: Text(homiziText(context, band.label)),
                  selected:
                      _draft.budgetMinInr == band.minInr &&
                      _draft.budgetMaxInr == band.maxInr,
                  onSelected: (_) => setState(() {
                    _draft = _draft.copyWith(
                      budgetMinInr: band.minInr,
                      budgetMaxInr: band.maxInr,
                      clearBudgetMin: band.minInr == null,
                      clearBudget: band.maxInr == null,
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('filter-move-in'),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year + 2),
                initialDate: _draft.moveInBy ?? now,
              );
              if (picked != null) {
                setState(() => _draft = _draft.copyWith(moveInBy: picked));
              }
            },
            child: Text(
              homiziText(
                context,
                _draft.moveInBy == null
                    ? 'Move-in on or before · Any'
                    : 'Move-in on or before · ${_draft.moveInBy!.year}-${_draft.moveInBy!.month.toString().padLeft(2, '0')}-${_draft.moveInBy!.day.toString().padLeft(2, '0')}',
              ),
            ),
          ),
          if (_draft.moveInBy != null)
            TextButton(
              onPressed: () =>
                  setState(() => _draft = _draft.copyWith(clearMoveIn: true)),
              child: Text(homiziText(context, 'Clear move-in date')),
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
            options: {
              null: 'Any',
              for (final type in filterPropertyTypes)
                type: propertyTypeLabelOf(type),
            },
            onChanged: (value) => setState(() {
              _draft = value == null
                  ? _draft.copyWith(clearPropertyType: true)
                  : _draft.copyWith(propertyType: value);
            }),
          ),
          HomiziRangeField(
            label: 'Built-up area (sq ft)',
            min: AreaRangeScale.min,
            max: AreaRangeScale.max,
            step: AreaRangeScale.step,
            start: _draft.areaMinSqft ?? AreaRangeScale.min,
            end: _draft.areaMaxSqft ?? AreaRangeScale.max,
            formatValue: formatSqft,
            openAtBounds: true,
            minSemantics: 'Minimum area',
            maxSemantics: 'Maximum area',
            sliderKey: const Key('filter-area-slider'),
            valueKey: const Key('filter-area-value'),
            onChanged: (start, end) => setState(() {
              final open = openBounds(
                start: start,
                end: end,
                min: AreaRangeScale.min,
                max: AreaRangeScale.max,
              );
              _draft = _draft.copyWith(
                areaMinSqft: open.start,
                areaMaxSqft: open.end,
                clearAreaMin: open.start == null,
                clearAreaMax: open.end == null,
              );
            }),
          ),
          const SectionLabel('Area band'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final band in areaBands)
                FilterChip(
                  label: Text(homiziText(context, band.label)),
                  selected:
                      _draft.areaMinSqft == band.minSqft &&
                      _draft.areaMaxSqft == band.maxSqft,
                  onSelected: (_) => setState(() {
                    _draft = _draft.copyWith(
                      areaMinSqft: band.minSqft,
                      areaMaxSqft: band.maxSqft,
                      clearAreaMin: band.minSqft == null,
                      clearAreaMax: band.maxSqft == null,
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const SectionLabel('Preferred tenants'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                label: Text(homiziText(context, 'Any')),
                selected: _draft.preferredTenant == null,
                onSelected: (_) => setState(
                  () => _draft = _draft.copyWith(clearPreferredTenant: true),
                ),
              ),
              for (final key in preferredTenantKeys)
                if (key != 'any')
                  FilterChip(
                    label: Text(homiziText(context, preferredTenantLabel(key))),
                    selected: _draft.preferredTenant == key,
                    onSelected: (_) => setState(
                      () => _draft = _draft.copyWith(preferredTenant: key),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Parking')),
            value: _draft.parking == true,
            onChanged: (value) => setState(() {
              _draft = value
                  ? _draft.copyWith(parking: true)
                  : _draft.copyWith(clearParking: true);
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Pets allowed')),
            value: _draft.petsAllowed == true,
            onChanged: (value) => setState(() {
              _draft = value
                  ? _draft.copyWith(petsAllowed: true)
                  : _draft.copyWith(clearPets: true);
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Non-veg allowed')),
            value: _draft.nonVegAllowed == true,
            onChanged: (value) => setState(() {
              _draft = value
                  ? _draft.copyWith(nonVegAllowed: true)
                  : _draft.copyWith(clearNonVeg: true);
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Gated society')),
            value: _draft.gatedSociety == true,
            onChanged: (value) => setState(() {
              _draft = value
                  ? _draft.copyWith(gatedSociety: true)
                  : _draft.copyWith(clearGated: true);
            }),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Photos only')),
            value: _draft.photosOnly,
            onChanged: (value) =>
                setState(() => _draft = _draft.copyWith(photosOnly: value)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Verified hosts only')),
            value: _draft.verifiedHostsOnly,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(verifiedHostsOnly: value),
            ),
          ),
          HomiziRangeField(
            label: 'Floor',
            min: FloorRangeScale.min,
            max: FloorRangeScale.max,
            step: FloorRangeScale.step,
            start: _draft.floorMin ?? FloorRangeScale.min,
            end: _draft.floorMax ?? FloorRangeScale.max,
            formatValue: _floorLabel,
            openAtBounds: true,
            minSemantics: 'Minimum floor',
            maxSemantics: 'Maximum floor',
            sliderKey: const Key('filter-floor-slider'),
            valueKey: const Key('filter-floor-value'),
            onChanged: (start, end) => setState(() {
              final open = openBounds(
                start: start,
                end: end,
                min: FloorRangeScale.min,
                max: FloorRangeScale.max,
              );
              _draft = _draft.copyWith(
                floorMin: open.start,
                floorMax: open.end,
                clearFloorMin: open.start == null,
                clearFloorMax: open.end == null,
              );
            }),
          ),
          const SizedBox(height: 8),
          const SectionLabel('Floor band'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final band in floorBands)
                FilterChip(
                  label: Text(homiziText(context, band.label)),
                  selected:
                      _draft.floorMin == band.min &&
                      _draft.floorMax == band.max,
                  onSelected: (_) => setState(() {
                    _draft = _draft.copyWith(
                      floorMin: band.min,
                      floorMax: band.max,
                      clearFloorMin: band.min == null,
                      clearFloorMax: band.max == null,
                    );
                  }),
                ),
            ],
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
            onPressed: () => setState(() {
              _draft = const ListingFilters();
              _locality.clear();
            }),
            child: Text(homiziText(context, 'Reset')),
          ),
        ],
      ),
    );
  }
}

String _floorLabel(int value) => '$value';

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
