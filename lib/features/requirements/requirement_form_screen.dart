import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/inventory/inventory_providers.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';

const _knownCities = ['Bengaluru', 'Pune', 'Hyderabad', 'Mumbai', 'Delhi NCR'];

class RequirementFormScreen extends ConsumerStatefulWidget {
  const RequirementFormScreen({super.key});

  @override
  ConsumerState<RequirementFormScreen> createState() =>
      _RequirementFormScreenState();
}

class _RequirementFormScreenState extends ConsumerState<RequirementFormScreen> {
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _locality = TextEditingController();
  String? _id;
  String _city = 'Bengaluru';
  DateTime? _moveIn;
  int _occupancy = 1;
  List<String> _errors = const [];
  String? _note;
  var _loading = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _locality.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loaded = await ref
          .read(inventoryGatewayProvider)
          .loadLatestRequirement();
      if (!mounted) {
        return;
      }
      if (loaded != null) {
        _id = loaded.id;
        _city = loaded.city.isEmpty ? _city : loaded.city;
        _locality.text = loaded.locality;
        _min.text = loaded.budgetMinInr?.toString() ?? '';
        _max.text = loaded.budgetMaxInr?.toString() ?? '';
        _moveIn = loaded.moveInDate;
        _occupancy = loaded.occupancy;
      }
    } on InventoryFailure catch (error) {
      _note = error.message;
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  RequirementDraft _draft() {
    return RequirementDraft(
      id: _id,
      budgetMinInr: int.tryParse(_min.text.trim()),
      budgetMaxInr: int.tryParse(_max.text.trim()),
      city: _city,
      locality: _locality.text,
      moveInDate: _moveIn,
      occupancy: _occupancy,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: _moveIn ?? now,
    );
    if (picked != null) {
      setState(() => _moveIn = picked);
    }
  }

  Future<void> _write({required bool publish}) async {
    final draft = _draft();
    final errors = draft.errors(today: DateTime.now());
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
        _note = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _errors = const [];
    });
    try {
      final gateway = ref.read(inventoryGatewayProvider);
      final result = publish
          ? await gateway.publishRequirement(draft)
          : await gateway.saveRequirement(draft);
      if (!mounted) {
        return;
      }
      setState(() {
        _id = result.draft.id;
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
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(key: Key('requirement-loading')),
        ),
      );
    }
    final moveLabel = _moveIn == null
        ? 'Choose a move-in date'
        : '${_moveIn!.year}-${_moveIn!.month.toString().padLeft(2, '0')}-${_moveIn!.day.toString().padLeft(2, '0')}';
    final cities = [
      ..._knownCities,
      if (!_knownCities.contains(_city) && _city.isNotEmpty) _city,
    ];
    final draft = _draft();
    final ready = draft.errors(today: DateTime.now()).isEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('What you need')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Budget, city, locality, move-in, and occupancy. Saving does not publish. Lifestyle scoring does not use gender, religion, caste, or age.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _city,
            decoration: const InputDecoration(labelText: 'City'),
            items: [
              for (final city in cities)
                DropdownMenuItem(value: city, child: Text(city)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _city = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('requirement-locality'),
            controller: _locality,
            decoration: const InputDecoration(
              labelText: 'Locality',
              hintText: 'Koramangala',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('requirement-min'),
            controller: _min,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minimum budget (₹)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('requirement-max'),
            controller: _max,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Maximum budget (₹)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Occupancy'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _occupancy > 1
                      ? () => setState(() => _occupancy -= 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$_occupancy'),
                IconButton(
                  onPressed: _occupancy < 20
                      ? () => setState(() => _occupancy += 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          OutlinedButton(onPressed: _pickDate, child: Text(moveLabel)),
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final error in _errors)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(_note!, key: const Key('requirement-note')),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('requirement-save'),
            onPressed: _busy ? null : () => unawaited(_write(publish: false)),
            child: const Text('Save draft'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('requirement-publish'),
            onPressed: _busy || !ready
                ? null
                : () => unawaited(_write(publish: true)),
            child: Text(_busy ? 'Publishing…' : 'Publish'),
          ),
        ],
      ),
    );
  }
}
