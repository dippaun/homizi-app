import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/poster_badge.dart';
import 'package:homizi/features/listings/domain/poster_kind.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';
import 'package:homizi/features/shared_home/host_shared_home_screen.dart';

/// PG owner's own homes and real join requests.
///
/// Demo tenant homes never appear here.
class PgOwnerHome extends ConsumerWidget {
  const PgOwnerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final published = [
      for (final home in ref.watch(publishedSearchProvider))
        if (home.listing.propertyType == 'pg' ||
            listingPosterKind(home.listing) == posterPg)
          home,
    ];
    final requests = ref.watch(hostJoinRequestsProvider);
    return Scaffold(
      key: const Key('pg-owner-home'),
      backgroundColor: HomiziColors.white,
      appBar: const PostPropertyBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const PosterKindBadge(kind: posterPg),
          const SizedBox(height: 10),
          Text(
            homiziText(context, 'Your PGs'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          if (published.isEmpty)
            _EmptyPg(onAdd: () => context.push('${RoutePaths.postPg}?list=1'))
          else
            for (final home in published)
              _PgCard(
                title: home.listing.title,
                place: '${home.listing.locality}, ${home.listing.city}',
                rent: home.listing.rentInr,
                onTap: () => context.push(RoutePaths.listing(home.listing.id)),
              ),
          const SizedBox(height: 18),
          Text(
            homiziText(context, 'Requests'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          requests.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
            error: (error, stack) => const _RequestNote(
              icon: Icons.wifi_off,
              title: 'Requests did not load',
              detail: 'Check the connection and open this page again.',
            ),
            data: (rows) {
              if (rows == null || rows.isEmpty) {
                return const _RequestNote(
                  icon: Icons.inbox_outlined,
                  title: 'No requests yet',
                  detail:
                      'When someone asks to join one of your PGs, it shows up here.',
                );
              }
              return Column(
                children: [
                  for (final row in rows)
                    _RequestCard(
                      name: row.firstName,
                      detail:
                          '${row.mode.name} · ${formatInr(row.shareInr)} / month',
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyPg extends StatelessWidget {
  const _EmptyPg({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pg-owner-empty'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1E4), Color(0xFFFFE0C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.night_shelter, color: Color(0xFF9A4B12), size: 36),
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Add your PG'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            homiziText(
              context,
              'Start with the address, then the rooms that are free. Photos come on the next page.',
            ),
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          ),
          const SizedBox(height: 14),
          PostGradientButton(
            buttonKey: const Key('pg-add'),
            label: 'Add your PG',
            showArrow: false,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _PgCard extends StatelessWidget {
  const _PgCard({
    required this.title,
    required this.place,
    required this.rent,
    required this.onTap,
  });

  final String title;
  final String place;
  final int rent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFFD7B0)),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFFBF6), Color(0xFFFFF1E4)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.night_shelter, color: Color(0xFF9A4B12)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: HomiziColors.ink,
                          ),
                        ),
                        Text(
                          place,
                          style: const TextStyle(color: HomiziColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatInr(rent),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestNote extends StatelessWidget {
  const _RequestNote({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pg-requests-empty'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: HomiziColors.homiziPurple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, title),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: HomiziColors.ink,
                  ),
                ),
                Text(
                  homiziText(context, detail),
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.name, required this.detail});

  final String name;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: const Color(0xFFF7F3FF),
        ),
        child: Row(
          children: [
            const Icon(Icons.person, color: HomiziColors.homiziPurple),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(detail),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
