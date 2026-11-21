import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/chat/open_profile_chat.dart';
import 'package:homizi/features/discovery/poster_badge.dart';
import 'package:homizi/features/listings/domain/poster_kind.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A published seeker whose preferences include a PG or a shared room.
class PgSeeker {
  const PgSeeker({
    required this.userId,
    required this.name,
    required this.city,
    required this.looking,
    required this.budget,
  });

  final String userId;
  final String name;
  final String city;
  final String looking;
  final String budget;
}

bool requirementWantsPg(Map<String, dynamic> row) {
  bool has(Object? value, Set<String> needles) {
    if (value is List) {
      return value.any((item) => needles.contains('$item'));
    }
    return needles.contains('$value');
  }

  const types = {'pg', 'shared_room'};
  const rooms = {'shared', 'shared_room', 'pg'};
  return has(row['property_types'], types) || has(row['room_type'], rooms);
}

PgSeeker? pgSeekerFromRows({
  required Map<String, dynamic> requirement,
  required Map<String, dynamic> profile,
}) {
  final id = profile['user_id']?.toString() ?? '';
  if (!isUuid(id)) {
    return null;
  }
  final min = _money(requirement['budget_min_inr']);
  final max = _money(requirement['budget_max_inr']);
  final budget = min == null && max == null
      ? 'Budget not set'
      : min != null && max != null
      ? '${formatInr(min)}–${formatInr(max)}'
      : max != null
      ? 'Up to ${formatInr(max)}'
      : 'From ${formatInr(min!)}';
  final looking = _looking(requirement);
  return PgSeeker(
    userId: id,
    name: _text(profile['display_name'], 'Tenant'),
    city: _text(requirement['city'], ''),
    looking: looking,
    budget: budget,
  );
}

final pgSeekersProvider = FutureProvider<List<PgSeeker>>((ref) async {
  final config = ref.watch(appConfigProvider);
  final session = ref.watch(sessionProvider);
  final self = session.userId;
  if (!config.connectsToSupabase ||
      ref.watch(forceDemoModeProvider) ||
      self == null ||
      !isUuid(self)) {
    return const [];
  }
  final client = Supabase.instance.client;
  final requirements = await client
      .from('listing_requirements')
      .select(
        'user_id, city, budget_min_inr, budget_max_inr, property_types, room_type',
      )
      .eq('status', 'published')
      .neq('user_id', self);
  final wanted = <Map<String, dynamic>>[];
  final ids = <String>{};
  for (final raw in requirements) {
    final row = Map<String, dynamic>.from(raw);
    final id = row['user_id']?.toString() ?? '';
    if (!requirementWantsPg(row) || !isUuid(id) || !ids.add(id)) {
      continue;
    }
    wanted.add(row);
  }
  if (wanted.isEmpty) {
    return const [];
  }
  final profiles = await client
      .from('profiles')
      .select('user_id, display_name')
      .inFilter('user_id', ids.toList());
  final byId = <String, Map<String, dynamic>>{
    for (final raw in profiles)
      if (raw['user_id'] is String)
        raw['user_id'] as String: Map<String, dynamic>.from(raw),
  };
  return [
    for (final row in wanted)
      if (byId[row['user_id']] != null)
        ?pgSeekerFromRows(requirement: row, profile: byId[row['user_id']]!),
  ];
});

/// Home for a PG owner: real seekers, then an empty state.
class PgSeekerHome extends ConsumerWidget {
  const PgSeekerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seekers = ref.watch(pgSeekersProvider);
    return ListView(
      key: const Key('pg-seeker-home'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        const PosterKindBadge(kind: posterPg),
        const SizedBox(height: 10),
        Text(
          homiziText(context, 'People looking for a PG'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          homiziText(
            context,
            'Seekers whose preferences include a PG or a shared room.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
        ),
        const SizedBox(height: 14),
        seekers.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (error, stack) => const _EmptySeekers(
            title: 'Seekers did not load',
            detail: 'Check the connection and open Home again.',
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return const _EmptySeekers(
                title: 'No PG seekers yet',
                detail:
                    'When someone publishes a preference for a PG or a shared room, they show up here.',
              );
            }
            return Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _SeekerCard(seeker: rows[i], index: i),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        PostGradientButton(
          buttonKey: const Key('pg-add'),
          label: 'Add your PG',
          showArrow: false,
          onPressed: () => context.push('${RoutePaths.postPg}?list=1'),
        ),
      ],
    );
  }
}

class _SeekerCard extends ConsumerWidget {
  const _SeekerCard({required this.seeker, required this.index});

  final PgSeeker seeker;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + index * 40),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: HomiziColors.white,
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
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    seeker.name,
                    key: Key('pg-seeker-${seeker.userId}'),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: HomiziColors.ink,
                    ),
                  ),
                  if (seeker.city.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      seeker.city,
                      style: const TextStyle(color: HomiziColors.inkSoft),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    seeker.looking,
                    style: const TextStyle(color: HomiziColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    seeker.budget,
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: Key('pg-seeker-message-${seeker.userId}'),
                      onPressed: () => openProfileChat(
                        context,
                        ref,
                        otherUserId: seeker.userId,
                        name: seeker.name,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text(homiziText(context, 'Message')),
                    ),
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

class _EmptySeekers extends StatelessWidget {
  const _EmptySeekers({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('pg-seeker-empty'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF1E4), Color(0xFFFFE0C2)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_search, color: Color(0xFF9A4B12), size: 36),
          const SizedBox(height: 8),
          Text(
            homiziText(context, title),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            homiziText(context, detail),
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          ),
        ],
      ),
    );
  }
}

String _looking(Map<String, dynamic> row) {
  final types = row['property_types'];
  final rooms = row['room_type'];
  final labels = <String>[];
  void add(Object? value) {
    if (value is List) {
      for (final item in value) {
        final label = _typeLabel('$item');
        if (label.isNotEmpty && !labels.contains(label)) {
          labels.add(label);
        }
      }
      return;
    }
    final label = _typeLabel('$value');
    if (label.isNotEmpty && !labels.contains(label)) {
      labels.add(label);
    }
  }

  add(types);
  add(rooms);
  if (labels.isEmpty) {
    return 'Looking for a PG';
  }
  return 'Looking for ${labels.join(' · ')}';
}

String _typeLabel(String value) {
  return switch (value) {
    'pg' => 'PG',
    'shared_room' || 'shared' => 'Shared room',
    _ => '',
  };
}

String _text(Object? value, String fallback) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

int? _money(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse('$value');
}
