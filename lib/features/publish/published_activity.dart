import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/publish/unverified_badge.dart';

enum PublishedKind { brief, home }

/// A brief or home this device is showing as published.
class PublishedActivityItem {
  const PublishedActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.place,
    required this.unverified,
    required this.onServer,
  });

  final String id;
  final PublishedKind kind;
  final String title;
  final String place;
  final bool unverified;
  final bool onServer;
}

class PublishedActivity extends Notifier<List<PublishedActivityItem>> {
  @override
  List<PublishedActivityItem> build() => const [];

  void remember(PublishedActivityItem item) {
    state = [
      item,
      for (final existing in state)
        if (existing.id != item.id) existing,
    ];
  }
}

final publishedActivityProvider =
    NotifierProvider<PublishedActivity, List<PublishedActivityItem>>(
      PublishedActivity.new,
    );

/// Rows under My activity for briefs and homes published from this device.
class PublishedActivitySection extends ConsumerWidget {
  const PublishedActivitySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(publishedActivityProvider);
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      key: const Key('activity-published'),
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.campaign_outlined, color: HomiziColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, item.title),
                        key: Key('activity-published-${item.id}'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: HomiziColors.ink),
                      ),
                      if (item.place.trim().isNotEmpty)
                        Text(
                          homiziText(context, item.place),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: HomiziColors.muted),
                        ),
                    ],
                  ),
                ),
                if (item.unverified) const UnverifiedBadge(),
              ],
            ),
          ),
      ],
    );
  }
}
