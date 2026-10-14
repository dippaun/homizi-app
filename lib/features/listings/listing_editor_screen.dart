import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';

class ListingEditorScreen extends ConsumerStatefulWidget {
  const ListingEditorScreen({super.key});

  @override
  ConsumerState<ListingEditorScreen> createState() =>
      _ListingEditorScreenState();
}

class _ListingEditorScreenState extends ConsumerState<ListingEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _locality;
  late final TextEditingController _rent;
  late final TextEditingController _deposit;
  var _loading = true;
  var _busy = false;
  var _step = 0;
  String? _note;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _locality = TextEditingController();
    _rent = TextEditingController();
    _deposit = TextEditingController();
    unawaited(_load());
  }

  Future<void> _load() async {
    final current = ref.read(listingDraftProvider);
    if (current.id != null || current.title.trim().isNotEmpty) {
      _applyControllers(current);
      _loading = false;
      return;
    }
    try {
      final loaded = await ref
          .read(inventoryGatewayProvider)
          .loadLatestListing();
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
  }

  @override
  void dispose() {
    _title.dispose();
    _locality.dispose();
    _rent.dispose();
    _deposit.dispose();
    super.dispose();
  }

  void _persist() {
    final current = ref.read(listingDraftProvider);
    ref
        .read(listingDraftProvider.notifier)
        .update(
          current.copyWith(
            title: _title.text,
            locality: _locality.text,
            rentText: _rent.text,
            depositText: _deposit.text,
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
              issue.contains('locality'))
            issue,
      ],
      1 => [
        for (final issue in blockers)
          if (issue.contains('rent') || issue.contains('deposit')) issue,
      ],
      _ => blockers,
    };
  }

  void _continue() {
    final issues = _stepIssues();
    if (issues.isNotEmpty) {
      setState(() => _note = issues.first);
      return;
    }
    setState(() {
      _note = null;
      _step = (_step + 1).clamp(0, 2);
    });
  }

  Future<void> _save() async {
    _persist();
    final draft = ref.read(listingDraftProvider);
    final issues = draft.persistBlockers();
    if (issues.isNotEmpty) {
      setState(() => _note = issues.first);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(inventoryGatewayProvider)
          .saveListing(draft);
      if (!mounted) {
        return;
      }
      final latest = ref.read(listingDraftProvider);
      ref
          .read(listingDraftProvider.notifier)
          .update(
            latest.copyWith(id: result.draft.id, photos: result.draft.photos),
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

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(listingDraftProvider);
    final cities = [
      'Bengaluru',
      'Pune',
      'Hyderabad',
      'Mumbai',
      'Delhi NCR',
      if (draft.city.isNotEmpty &&
          !const {
            'Bengaluru',
            'Pune',
            'Hyderabad',
            'Mumbai',
            'Delhi NCR',
          }.contains(draft.city))
        draft.city,
    ];
    final photoCount = draft.photos.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Property listing')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(key: Key('listing-loading')),
            )
          : Stepper(
              currentStep: _step,
              onStepTapped: (step) => setState(() => _step = step),
              controlsBuilder: (context, details) => const SizedBox.shrink(),
              steps: [
                Step(
                  title: const Text('Home'),
                  isActive: _step >= 0,
                  state: _step > 0 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Save stores a draft. Publish is a separate server check. This form cannot set listing status, verification, or payments.',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('listing-title'),
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title'),
                        onChanged: (_) => _persist(),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: draft.city.isEmpty ? null : draft.city,
                        decoration: const InputDecoration(labelText: 'City'),
                        items: [
                          for (final city in cities)
                            DropdownMenuItem(value: city, child: Text(city)),
                        ],
                        onChanged: (value) {
                          _persist();
                          ref
                              .read(listingDraftProvider.notifier)
                              .update(
                                ref
                                    .read(listingDraftProvider)
                                    .copyWith(city: value ?? ''),
                              );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('listing-locality'),
                        controller: _locality,
                        decoration: const InputDecoration(
                          labelText: 'Locality',
                        ),
                        onChanged: (_) => _persist(),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Rent'),
                  isActive: _step >= 1,
                  state: _step > 1 ? StepState.complete : StepState.indexed,
                  content: Column(
                    children: [
                      TextField(
                        key: const Key('listing-rent'),
                        controller: _rent,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Monthly rent (₹)',
                        ),
                        onChanged: (_) => _persist(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('listing-deposit'),
                        controller: _deposit,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Deposit (₹)',
                        ),
                        onChanged: (_) => _persist(),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: draft.furnishing,
                        decoration: const InputDecoration(
                          labelText: 'Furnishing',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'unfurnished',
                            child: Text('Unfurnished'),
                          ),
                          DropdownMenuItem(
                            value: 'semi_furnished',
                            child: Text('Semi-furnished'),
                          ),
                          DropdownMenuItem(
                            value: 'furnished',
                            child: Text('Furnished'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          ref
                              .read(listingDraftProvider.notifier)
                              .update(
                                ref
                                    .read(listingDraftProvider)
                                    .copyWith(furnishing: value),
                              );
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: draft.propertyType,
                        decoration: const InputDecoration(
                          labelText: 'Property type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'apartment',
                            child: Text('Apartment'),
                          ),
                          DropdownMenuItem(
                            value: 'private_room',
                            child: Text('Private room'),
                          ),
                          DropdownMenuItem(
                            value: 'shared_room',
                            child: Text('Shared room'),
                          ),
                          DropdownMenuItem(
                            value: 'studio',
                            child: Text('Studio'),
                          ),
                          DropdownMenuItem(
                            value: 'independent_house',
                            child: Text('Independent house'),
                          ),
                          DropdownMenuItem(
                            value: 'villa',
                            child: Text('Villa'),
                          ),
                          DropdownMenuItem(value: 'pg', child: Text('PG')),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          ref
                              .read(listingDraftProvider.notifier)
                              .update(
                                ref
                                    .read(listingDraftProvider)
                                    .copyWith(propertyType: value),
                              );
                        },
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Photos'),
                  isActive: _step >= 2,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        photoCount == 0
                            ? 'No photos yet. Add at least 3 before publish.'
                            : '$photoCount on this device. Publish needs 3, with one marked primary.',
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          _persist();
                          context.push(RoutePaths.photoManager);
                        },
                        child: const Text('Manage photos'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : Material(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_note != null)
                      Text(_note!, key: const Key('listing-save-note')),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_step < 2)
                          FilledButton(
                            key: const Key('listing-continue'),
                            onPressed: _continue,
                            child: const Text('Continue'),
                          ),
                        if (_step == 2) ...[
                          FilledButton(
                            key: const Key('save-listing'),
                            onPressed: _busy ? null : () => unawaited(_save()),
                            child: Text(_busy ? 'Saving…' : 'Save draft'),
                          ),
                          FilledButton(
                            onPressed: () {
                              _persist();
                              context.push(RoutePaths.listingPreview);
                            },
                            child: const Text('Preview listing'),
                          ),
                        ],
                        if (_step > 0)
                          TextButton(
                            onPressed: () => setState(() => _step -= 1),
                            child: const Text('Back'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
