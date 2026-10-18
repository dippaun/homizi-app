import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/roles/role_provider.dart';

/// Six-step listing wizard. Drafts autosave once the server can store them.
class ListingEditorScreen extends ConsumerStatefulWidget {
  const ListingEditorScreen({this.propertyId, this.fresh = false, super.key});

  /// Owned listing to edit. Null resumes the latest draft.
  final String? propertyId;

  /// Start empty instead of resuming a draft.
  final bool fresh;

  @override
  ConsumerState<ListingEditorScreen> createState() =>
      _ListingEditorScreenState();
}

class _ListingEditorScreenState extends ConsumerState<ListingEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _locality;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;
  late final TextEditingController _maintenance;
  late final TextEditingController _brokerage;
  late final TextEditingController _brokerageTerms;
  late final TextEditingController _address;
  late final TextEditingController _landmark;
  late final TextEditingController _area;
  late final TextEditingController _floor;
  late final TextEditingController _totalFloors;
  var _loading = true;
  var _busy = false;
  var _step = 0;
  String? _note;

  static const _stepTitles = <String>[
    'Basics',
    'Rent and deposit',
    'Amenities and house rules',
    'Preferred tenants',
    'Photos',
    'Review and publish',
  ];

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _locality = TextEditingController();
    _rent = TextEditingController();
    _deposit = TextEditingController();
    _maintenance = TextEditingController();
    _brokerage = TextEditingController();
    _brokerageTerms = TextEditingController();
    _address = TextEditingController();
    _landmark = TextEditingController();
    _area = TextEditingController();
    _floor = TextEditingController();
    _totalFloors = TextEditingController();
    unawaited(_load());
  }

  Future<void> _load() async {
    if (widget.fresh) {
      ref.read(listingDraftProvider.notifier).update(const ListingDraft());
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    final current = ref.read(listingDraftProvider);
    final wanted = widget.propertyId;
    if (wanted == null &&
        (current.id != null || current.title.trim().isNotEmpty)) {
      _applyControllers(current);
      _loading = false;
      return;
    }
    try {
      final loaded = await ref
          .read(inventoryGatewayProvider)
          .loadListingDraft(id: wanted);
      if (!mounted) {
        return;
      }
      if (loaded != null) {
        ref.read(listingDraftProvider.notifier).update(loaded);
        _applyControllers(loaded);
      }
    } on InventoryFailure catch (error) {
      _note = error.message;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _applyControllers(ListingDraft draft) {
    _title.text = draft.title;
    _locality.text = draft.locality;
    _rent.text = draft.rentText;
    _deposit.text = draft.depositText;
    _maintenance.text = draft.maintenanceText;
    _brokerage.text = draft.brokerageText;
    _brokerageTerms.text = draft.brokerageTerms;
    _address.text = draft.addressLine;
    _landmark.text = draft.landmark;
    _area.text = draft.areaText;
    _floor.text = draft.floorText;
    _totalFloors.text = draft.totalFloorsText;
  }

  @override
  void dispose() {
    _title.dispose();
    _locality.dispose();
    _rent.dispose();
    _deposit.dispose();
    _maintenance.dispose();
    _brokerage.dispose();
    _brokerageTerms.dispose();
    _address.dispose();
    _landmark.dispose();
    _area.dispose();
    _floor.dispose();
    _totalFloors.dispose();
    super.dispose();
  }

  void _persist() {
    final current = ref.read(listingDraftProvider);
    final broker = ref.read(currentRoleProvider) == HomiziRole.broker;
    ref
        .read(listingDraftProvider.notifier)
        .update(
          current.copyWith(
            title: _title.text,
            locality: _locality.text,
            rentText: _rent.text,
            depositText: _deposit.text,
            maintenanceText: _maintenance.text,
            brokerageText: _brokerage.text,
            addressLine: _address.text,
            landmark: _landmark.text,
            areaText: _area.text,
            floorText: _floor.text,
            totalFloorsText: _totalFloors.text,
            listedBy: broker ? 'broker' : current.listedBy,
            brokerageTerms: _brokerageTerms.text,
          ),
        );
  }

  List<String> _stepIssues() {
    _persist();
    final blockers = ref.read(listingDraftProvider).persistBlockers();
    return switch (_step) {
      0 => [
        for (final issue in blockers)
          if (issue.contains('title') ||
              issue.contains('city') ||
              issue.contains('locality') ||
              issue.contains('street'))
            issue,
      ],
      1 => [
        for (final issue in blockers)
          if (issue.contains('rent') ||
              issue.contains('deposit') ||
              issue.contains('maintenance') ||
              issue.contains('charges') ||
              issue.contains('Occupancy') ||
              issue.contains('area') ||
              issue.toLowerCase().contains('floor'))
            issue,
      ],
      3 => [
        for (final issue in blockers)
          if (issue.contains('preferred tenants') ||
              issue.contains('who the home suits'))
            issue,
      ],
      _ => const <String>[],
    };
  }

  Future<bool> _autosave() async {
    _persist();
    final draft = ref.read(listingDraftProvider);
    if (draft.persistBlockers().isNotEmpty) {
      return true;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(inventoryGatewayProvider)
          .saveListing(draft);
      if (!mounted) {
        return false;
      }
      ref
          .read(listingDraftProvider.notifier)
          .update(
            ref
                .read(listingDraftProvider)
                .copyWith(id: result.draft.id, photos: result.draft.photos),
          );
      setState(() {
        _note = result.message;
        _busy = false;
      });
      return true;
    } on InventoryFailure catch (error) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _note = error.message;
        _busy = false;
      });
      return false;
    }
  }

  Future<void> _continue() async {
    final issues = _stepIssues();
    if (issues.isNotEmpty) {
      setState(() => _note = issues.first);
      return;
    }
    if (_step >= 1) {
      final saved = await _autosave();
      if (!saved || !mounted) {
        return;
      }
    }
    setState(() {
      _note = null;
      _step = (_step + 1).clamp(0, _stepTitles.length - 1);
    });
  }

  Future<void> _save() async {
    final saved = await _autosave();
    if (!saved || !mounted) {
      return;
    }
    final issues = ref.read(listingDraftProvider).persistBlockers();
    if (issues.isNotEmpty) {
      setState(() => _note = issues.first);
    }
  }

  Future<void> _submitReview() async {
    final saved = await _autosave();
    if (!saved || !mounted) {
      return;
    }
    final id = ref.read(listingDraftProvider).id;
    if (id == null) {
      setState(
        () => _note = 'Add a title, a city, a locality, and the rent first.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final message = await ref
          .read(ownerGatewayProvider)
          .act(id, 'submit_review');
      if (!mounted) {
        return;
      }
      setState(() {
        _note = message;
        _busy = false;
      });
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _note = error.message;
        _busy = false;
      });
    }
  }

  Future<void> _publish() async {
    _persist();
    final draft = ref.read(listingDraftProvider);
    final issues = draft.publishBlockers();
    if (issues.isNotEmpty) {
      setState(() => _note = issues.first);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(inventoryGatewayProvider)
          .publishListing(draft);
      if (!mounted) {
        return;
      }
      ref
          .read(listingDraftProvider.notifier)
          .update(
            ref
                .read(listingDraftProvider)
                .copyWith(id: result.draft.id, photos: result.draft.photos),
          );
      setState(() {
        _note = result.message;
        _busy = false;
      });
    } on InventoryFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _note = error.message;
        _busy = false;
      });
    }
  }

  void _toggle(
    String key,
    bool selected,
    List<String> Function(ListingDraft current) read,
    ListingDraft Function(ListingDraft current, List<String> next) write,
  ) {
    _persist();
    final current = ref.read(listingDraftProvider);
    final next = [
      for (final item in read(current))
        if (item != key) item,
      if (selected) key,
    ];
    ref.read(listingDraftProvider.notifier).update(write(current, next));
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(listingDraftProvider);
    final last = _step == _stepTitles.length - 1;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'List your home'))),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(key: Key('listing-loading')),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(
                          context,
                          'Step ${_step + 1} of ${_stepTitles.length}',
                        ),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_step + 1) / _stepTitles.length,
                        color: HomiziColors.accent,
                        backgroundColor: HomiziColors.mist,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        homiziText(context, _stepTitles[_step]),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      if (_step == 0) _basics(context, draft),
                      if (_step == 1) _rentFields(context, draft),
                      if (_step == 2) _amenities(context, draft),
                      if (_step == 3) _tenants(context, draft),
                      if (_step == 4) _photos(context, draft),
                      if (_step == 5) _review(context, draft),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : Material(
              color: HomiziColors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_note != null)
                        Text(
                          homiziText(context, _note!),
                          key: const Key('listing-save-note'),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!last)
                            FilledButton(
                              key: const Key('listing-continue'),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(_continue()),
                              child: Text(homiziText(context, 'Continue')),
                            ),
                          if (last) ...[
                            FilledButton(
                              key: const Key('save-listing'),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(_save()),
                              child: Text(
                                homiziText(
                                  context,
                                  _busy ? 'Saving…' : 'Save draft',
                                ),
                              ),
                            ),
                            FilledButton(
                              key: const Key('listing-submit-review'),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(_submitReview()),
                              child: Text(
                                homiziText(context, 'Submit for review'),
                              ),
                            ),
                            FilledButton(
                              key: const Key('listing-review-publish'),
                              onPressed: _busy
                                  ? null
                                  : () => unawaited(_publish()),
                              child: Text(homiziText(context, 'Publish')),
                            ),
                            OutlinedButton(
                              onPressed: () {
                                _persist();
                                context.push(RoutePaths.listingPreview);
                              },
                              child: Text(
                                homiziText(context, 'Preview listing'),
                              ),
                            ),
                          ],
                          if (_step > 0)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _step -= 1),
                              child: Text(homiziText(context, 'Back')),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _basics(BuildContext context, ListingDraft draft) {
    final cities = [
      ...exploreCities,
      if (draft.city.isNotEmpty && !exploreCities.contains(draft.city))
        draft.city,
    ];
    return Column(
      children: [
        Text(
          homiziText(
            context,
            'Save stores a draft. Publish is a separate server check. This form cannot set listing status, verification, or payments.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('listing-title'),
          controller: _title,
          decoration: InputDecoration(labelText: homiziText(context, 'Title')),
          onChanged: (_) => _persist(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: draft.city.isEmpty ? null : draft.city,
          decoration: InputDecoration(labelText: homiziText(context, 'City')),
          items: [
            for (final city in cities)
              DropdownMenuItem(
                value: city,
                child: Text(homiziText(context, city)),
              ),
          ],
          onChanged: (value) {
            _persist();
            ref
                .read(listingDraftProvider.notifier)
                .update(
                  ref.read(listingDraftProvider).copyWith(city: value ?? ''),
                );
          },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-locality'),
          controller: _locality,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Locality'),
          ),
          onChanged: (_) => _persist(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: draft.propertyType,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Property type'),
          ),
          items: [
            for (final item in const [
              ('apartment', 'Apartment'),
              ('private_room', 'Private room'),
              ('shared_room', 'Shared room'),
              ('studio', 'Studio'),
              ('independent_house', 'Independent house'),
              ('villa', 'Villa'),
              ('pg', 'PG'),
            ])
              DropdownMenuItem(
                value: item.$1,
                child: Text(homiziText(context, item.$2)),
              ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            ref
                .read(listingDraftProvider.notifier)
                .update(
                  ref.read(listingDraftProvider).copyWith(propertyType: value),
                );
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: draft.furnishing,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Furnishing'),
          ),
          items: [
            for (final item in const [
              ('unfurnished', 'Unfurnished'),
              ('semi_furnished', 'Semi-furnished'),
              ('furnished', 'Furnished'),
            ])
              DropdownMenuItem(
                value: item.$1,
                child: Text(homiziText(context, item.$2)),
              ),
          ],
          onChanged: (value) {
            if (value == null) {
              return;
            }
            ref
                .read(listingDraftProvider.notifier)
                .update(
                  ref.read(listingDraftProvider).copyWith(furnishing: value),
                );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'Occupancy')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: homiziText(context, 'Fewer people'),
                onPressed: draft.occupancy > 1
                    ? () {
                        _persist();
                        ref
                            .read(listingDraftProvider.notifier)
                            .update(
                              ref
                                  .read(listingDraftProvider)
                                  .copyWith(occupancy: draft.occupancy - 1),
                            );
                      }
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text('${draft.occupancy}'),
              IconButton(
                tooltip: homiziText(context, 'More people'),
                onPressed: draft.occupancy < 20
                    ? () {
                        _persist();
                        ref
                            .read(listingDraftProvider.notifier)
                            .update(
                              ref
                                  .read(listingDraftProvider)
                                  .copyWith(occupancy: draft.occupancy + 1),
                            );
                      }
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        TextField(
          key: const Key('listing-address'),
          controller: _address,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Street address'),
            helperText: homiziText(
              context,
              'Saved privately. Shown only after a visit is agreed.',
            ),
          ),
          onChanged: (_) => _persist(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-landmark'),
          controller: _landmark,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Landmark'),
          ),
          onChanged: (_) => _persist(),
        ),
      ],
    );
  }

  Widget _rentFields(BuildContext context, ListingDraft draft) {
    return Column(
      children: [
        TextField(
          key: const Key('listing-rent'),
          controller: _rent,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Monthly rent (₹)'),
          ),
          onChanged: (_) => _persist(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-deposit'),
          controller: _deposit,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Deposit (₹)'),
          ),
          onChanged: (_) => _persist(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-maintenance'),
          controller: _maintenance,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Maintenance (₹)'),
          ),
          onChanged: (_) => _persist(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-charges'),
          controller: _brokerage,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Other monthly charges (₹)'),
          ),
          onChanged: (_) => _persist(),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Brokerage stays zero. Use other monthly charges only for society or utility amounts you want shown.',
          ),
        ),
        if (ref.watch(currentRoleProvider) == HomiziRole.broker ||
            draft.listedBy == 'broker') ...[
          const SizedBox(height: 12),
          const BrokerChip(),
          const SizedBox(height: 12),
          TextField(
            key: const Key('listing-brokerage-terms'),
            controller: _brokerageTerms,
            maxLength: 160,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Brokerage terms'),
              hintText: homiziText(
                context,
                'One month rent, paid when the agreement is signed',
              ),
            ),
            onChanged: (_) => _persist(),
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-area'),
          controller: _area,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Built-up area (sq ft)'),
          ),
          onChanged: (_) => _persist(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-floor'),
          controller: _floor,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: homiziText(context, 'Floor')),
          onChanged: (_) => _persist(),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('listing-total-floors'),
          controller: _totalFloors,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Total floors'),
          ),
          onChanged: (_) => _persist(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'Parking')),
          value: draft.parking,
          onChanged: (value) {
            _persist();
            ref
                .read(listingDraftProvider.notifier)
                .update(
                  ref.read(listingDraftProvider).copyWith(parking: value),
                );
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'Pets allowed')),
          value: draft.petsAllowed,
          onChanged: (value) {
            _persist();
            ref
                .read(listingDraftProvider.notifier)
                .update(
                  ref.read(listingDraftProvider).copyWith(petsAllowed: value),
                );
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'Non-veg allowed')),
          value: draft.nonVegAllowed,
          onChanged: (value) {
            _persist();
            ref
                .read(listingDraftProvider.notifier)
                .update(
                  ref.read(listingDraftProvider).copyWith(nonVegAllowed: value),
                );
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(homiziText(context, 'Gated society')),
          value: draft.gatedSociety,
          onChanged: (value) {
            _persist();
            ref
                .read(listingDraftProvider.notifier)
                .update(
                  ref.read(listingDraftProvider).copyWith(gatedSociety: value),
                );
          },
        ),
      ],
    );
  }

  Widget _amenities(BuildContext context, ListingDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChipSet(
          label: 'Amenities',
          options: listingAmenities,
          labelFor: listingAmenityLabel,
          selected: draft.amenities,
          onToggle: (key, selected) => _toggle(
            key,
            selected,
            (current) => current.amenities,
            (current, next) => current.copyWith(amenities: next),
          ),
        ),
        _ChipSet(
          label: 'House rules',
          options: listingRestrictions,
          labelFor: listingRestrictionLabel,
          selected: draft.restrictions,
          onToggle: (key, selected) => _toggle(
            key,
            selected,
            (current) => current.restrictions,
            (current, next) => current.copyWith(restrictions: next),
          ),
        ),
      ],
    );
  }

  Widget _tenants(BuildContext context, ListingDraft draft) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(
            context,
            'Choose who the home suits. This is a preference, not a filter on gender, religion, or caste.',
          ),
        ),
        const SizedBox(height: 12),
        _ChipSet(
          label: 'Preferred tenants',
          options: listingSuitability,
          labelFor: listingSuitabilityLabel,
          selected: draft.suitability,
          onToggle: (key, selected) => _toggle(
            key,
            selected,
            (current) => current.suitability,
            (current, next) => current.copyWith(suitability: next),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final key in preferredTenantKeys)
              FilterChip(
                label: Text(homiziText(context, preferredTenantLabel(key))),
                selected: draft.preferredTenants.contains(key),
                onSelected: (selected) {
                  _persist();
                  final current = ref.read(listingDraftProvider);
                  final next = [
                    for (final item in current.preferredTenants)
                      if (item != key &&
                          !(key != 'any' && item == 'any') &&
                          !(key == 'any' && item != 'any'))
                        item,
                    if (selected) key,
                  ];
                  ref
                      .read(listingDraftProvider.notifier)
                      .update(current.copyWith(preferredTenants: next));
                },
              ),
          ],
        ),
      ],
    );
  }

  Widget _photos(BuildContext context, ListingDraft draft) {
    final photoCount = draft.photos.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(
            context,
            photoCount == 0
                ? 'No photos yet. Add at least 3 before publish.'
                : '$photoCount on this device. Publish needs 3, with a room marked primary. Room photos come before exterior shots.',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            _persist();
            await context.push(RoutePaths.photoManager);
            if (mounted) {
              await _autosave();
            }
          },
          child: Text(homiziText(context, 'Manage photos')),
        ),
      ],
    );
  }

  Widget _review(BuildContext context, ListingDraft draft) {
    final blockers = draft.publishBlockers();
    final rent = draft.rentInr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(
            context,
            draft.title.trim().isEmpty ? 'Untitled home' : draft.title.trim(),
          ),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          homiziText(context, '${draft.locality.trim()}, ${draft.city.trim()}'),
        ),
        const SizedBox(height: 6),
        Text(
          homiziText(
            context,
            rent == null ? 'Rent not set' : '${formatInr(rent)} / month',
          ),
        ),
        const SizedBox(height: 12),
        _choiceLine(
          context,
          label: 'Amenities',
          empty: 'None yet',
          values: [for (final key in draft.amenities) listingAmenityLabel(key)],
        ),
        _choiceLine(
          context,
          label: 'House rules',
          empty: 'None yet',
          values: [
            for (final key in draft.restrictions) listingRestrictionLabel(key),
          ],
        ),
        _choiceLine(
          context,
          label: 'Preferred tenants',
          empty: 'Any',
          values: [
            for (final key in draft.suitability) listingSuitabilityLabel(key),
          ],
        ),
        const SizedBox(height: 6),
        Text(homiziText(context, '${draft.photos.length} photos')),
        const SizedBox(height: 16),
        if (blockers.isEmpty)
          Text(
            homiziText(
              context,
              'Ready to publish. The server still checks at least 3 photos and a room as the primary photo.',
            ),
          )
        else
          for (final issue in blockers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(homiziText(context, issue)),
            ),
      ],
    );
  }
}

Widget _choiceLine(
  BuildContext context, {
  required String label,
  required String empty,
  required List<String> values,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(homiziText(context, label)),
        const SizedBox(height: 4),
        if (values.isEmpty)
          Text(homiziText(context, empty))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final value in values) Text(homiziText(context, value)),
            ],
          ),
      ],
    ),
  );
}

class _ChipSet extends StatelessWidget {
  const _ChipSet({
    required this.label,
    required this.options,
    required this.labelFor,
    required this.selected,
    required this.onToggle,
  });

  final String label;
  final List<String> options;
  final String Function(String key) labelFor;
  final List<String> selected;
  final void Function(String key, bool selected) onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(homiziText(context, label)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                FilterChip(
                  label: Text(homiziText(context, labelFor(option))),
                  selected: selected.contains(option),
                  onSelected: (value) => onToggle(option, value),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
