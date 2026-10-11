import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
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
  var _seeded = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _locality = TextEditingController();
    _rent = TextEditingController();
    _deposit = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) {
      return;
    }
    final draft = ref.read(listingDraftProvider);
    _title.text = draft.title;
    _locality.text = draft.locality;
    _rent.text = draft.rentText;
    _deposit.text = draft.depositText;
    _seeded = true;
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

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(listingDraftProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Property listing')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Required fields are marked by the publish check. Verification and paid plans cannot be set from this form.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
            onChanged: (_) => _persist(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: draft.city.isEmpty ? null : draft.city,
            decoration: const InputDecoration(labelText: 'City'),
            items: const [
              DropdownMenuItem(value: 'Bengaluru', child: Text('Bengaluru')),
              DropdownMenuItem(value: 'Pune', child: Text('Pune')),
              DropdownMenuItem(value: 'Hyderabad', child: Text('Hyderabad')),
              DropdownMenuItem(value: 'Mumbai', child: Text('Mumbai')),
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
            controller: _locality,
            decoration: const InputDecoration(labelText: 'Locality'),
            onChanged: (_) => _persist(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rent,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monthly rent (₹)'),
            onChanged: (_) => _persist(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _deposit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Deposit (₹)'),
            onChanged: (_) => _persist(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: draft.furnishing,
            decoration: const InputDecoration(labelText: 'Furnishing'),
            items: const [
              DropdownMenuItem(
                value: 'unfurnished',
                child: Text('Unfurnished'),
              ),
              DropdownMenuItem(
                value: 'semi_furnished',
                child: Text('Semi-furnished'),
              ),
              DropdownMenuItem(value: 'furnished', child: Text('Furnished')),
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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: draft.propertyType,
            decoration: const InputDecoration(labelText: 'Property type'),
            items: const [
              DropdownMenuItem(value: 'apartment', child: Text('Apartment')),
              DropdownMenuItem(
                value: 'private_room',
                child: Text('Private room'),
              ),
              DropdownMenuItem(
                value: 'shared_room',
                child: Text('Shared room'),
              ),
              DropdownMenuItem(value: 'studio', child: Text('Studio')),
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
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () {
              _persist();
              context.push(RoutePaths.photoManager);
            },
            child: const Text('Manage photos'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              _persist();
              context.push(RoutePaths.listingPreview);
            },
            child: const Text('Preview listing'),
          ),
        ],
      ),
    );
  }
}
