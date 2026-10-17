import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/owner/listing_stats_chart.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/owner/owner_rules.dart';

final listingStatsProvider = FutureProvider.autoDispose
    .family<ListingStats, String>((ref, propertyId) {
      return ref.watch(ownerGatewayProvider).stats(propertyId);
    });

class ListingStatsScreen extends ConsumerStatefulWidget {
  const ListingStatsScreen({required this.propertyId, super.key});

  final String propertyId;

  @override
  ConsumerState<ListingStatsScreen> createState() => _ListingStatsScreenState();
}

class _ListingStatsScreenState extends ConsumerState<ListingStatsScreen> {
  var _days = 7;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(listingStatsProvider(widget.propertyId));
    return Scaffold(
      key: const Key('listing-stats-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Listing performance'))),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  homiziText(
                    context,
                    error is OwnerFailure
                        ? error.message
                        : 'Stats did not load.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.invalidate(listingStatsProvider(widget.propertyId)),
                  child: Text(homiziText(context, 'Try again')),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final window = trailingDays(data.days, _days);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                homiziText(
                  context,
                  'Views, saves, and interests for this listing. Only you can see this.',
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 7,
                    label: Text(homiziText(context, '7 days')),
                  ),
                  ButtonSegment(
                    value: 30,
                    label: Text(homiziText(context, '30 days')),
                  ),
                ],
                selected: {_days},
                onSelectionChanged: (value) {
                  setState(() => _days = value.first);
                },
              ),
              const SizedBox(height: 16),
              Text(
                homiziText(context, '${data.viewsFor(_days)} views'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              ListingStatsChart(days: window),
              const SizedBox(height: 16),
              _StatTile(label: '${data.saves} saves'),
              _StatTile(label: '${data.interests} interests'),
              _StatTile(label: '${data.visitRequests} visit requests'),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.insights_outlined, color: HomiziColors.accent),
      title: Text(homiziText(context, label)),
    );
  }
}
