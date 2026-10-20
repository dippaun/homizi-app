import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/discovery/feed_controller.dart';

const _places = <String>[
  'Koramangala',
  'Indiranagar',
  'HSR Layout',
  'Whitefield',
  'Bandra West',
  'Andheri East',
  'Powai',
  'Jubilee Hills',
];

class TenantSearchScreen extends ConsumerStatefulWidget {
  const TenantSearchScreen({super.key});

  @override
  ConsumerState<TenantSearchScreen> createState() => _TenantSearchScreenState();
}

class _TenantSearchScreenState extends ConsumerState<TenantSearchScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _open(String raw) {
    final query = raw.trim().isEmpty ? 'Indiranagar' : raw.trim();
    ref.read(listingFilterProvider.notifier).setQuery(query);
    context.go(RoutePaths.explore);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('tenant-search-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Search homes')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            homiziText(context, 'Where do you want to live?'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'Try a locality in Bengaluru, Mumbai, or Hyderabad. Results open in Explore.',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('tenant-search-field'),
            controller: _query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Locality or home'),
              hintText: homiziText(context, '2 BHK in Indiranagar'),
            ),
            onSubmitted: _open,
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('tenant-search-submit'),
            onPressed: () => _open(_query.text),
            child: Text(homiziText(context, 'Show homes')),
          ),
          const SizedBox(height: 24),
          Text(
            homiziText(context, 'Popular localities'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final place in _places)
                ActionChip(
                  key: Key(
                    'tenant-search-chip-${place.toLowerCase().replaceAll(' ', '-')}',
                  ),
                  label: Text(homiziText(context, place)),
                  onPressed: () => _open(place),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
