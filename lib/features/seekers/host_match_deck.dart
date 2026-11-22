import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/core/supabase/missing_relation.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_home_bar.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/chat/open_profile_chat.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/roommate_deck_card.dart';
import 'package:homizi/features/seekers/host_seeker_score.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Host Matches. Live seekers only, scored both ways against a published home.
class HostMatchDeck extends ConsumerStatefulWidget {
  const HostMatchDeck({super.key});

  @override
  ConsumerState<HostMatchDeck> createState() => _HostMatchDeckState();
}

class _HostMatchDeckState extends ConsumerState<HostMatchDeck> {
  var _loading = true;
  String? _error;
  List<HostSeekerFit> _fits = const [];
  final _gone = <String>{};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final listings = await _listings();
      final seekers = await _seekers();
      final fits = <HostSeekerFit>[];
      for (final seeker in seekers) {
        final fit = bestHostFit(seeker: seeker, listings: listings);
        if (fit != null) {
          fits.add(fit);
        }
      }
      fits.sort((a, b) {
        final aLocal = samePlaceCity(a.seeker.city, a.listing.city);
        final bLocal = samePlaceCity(b.seeker.city, b.listing.city);
        if (aLocal != bLocal) {
          return aLocal ? -1 : 1;
        }
        return b.percent.compareTo(a.percent);
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _fits = fits;
        _loading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Seekers did not load.';
      });
    }
  }

  Future<List<Listing>> _listings() async {
    final published = [
      for (final home in ref.read(publishedSearchProvider)) home.listing,
    ];
    if (published.isNotEmpty) {
      return published;
    }
    try {
      final owned = await ref.read(ownerGatewayProvider).myListings();
      return [
        for (final row in owned)
          if (row.status == 'published' || row.chip == 'live')
            Listing(
              id: row.id,
              hostUserId: ref.read(sessionProvider).userId ?? '',
              title: row.title,
              city: row.city,
              locality: row.locality,
              rentInr: row.rentInr,
              depositInr: 0,
              furnishing: '',
              propertyType: 'apartment',
              hostDisplayName: '',
              amenities: const [],
              summary: '',
            ),
      ];
    } on Object {
      return const [];
    }
  }

  Future<List<HostLiveSeeker>> _seekers() async {
    final config = ref.read(appConfigProvider);
    final self = ref.read(sessionProvider).userId;
    if (!config.connectsToSupabase ||
        ref.read(forceDemoModeProvider) ||
        self == null ||
        !isUuid(self)) {
      return const [];
    }
    final client = Supabase.instance.client;
    try {
      final raw = await client.rpc<dynamic>('host_live_seekers');
      return _parseRows(raw is List ? raw : const []);
    } on Object catch (error) {
      if (!isMissingRelation(error)) {
        rethrow;
      }
    }
    final rows = await client
        .from('listing_requirements')
        .select(
          'user_id, city, localities, budget_min_inr, budget_max_inr, property_types, room_type, about_me, profession, move_in_date',
        )
        .eq('status', 'published')
        .eq('discoverable', true)
        .neq('user_id', self);
    final ids = <String>[
      for (final raw in rows)
        if (raw['user_id'] is String && isUuid(raw['user_id'] as String))
          raw['user_id'] as String,
    ];
    if (ids.isEmpty) {
      return const [];
    }
    final profiles = await client
        .from('profiles')
        .select('user_id, display_name, occupation, avatar_path')
        .inFilter('user_id', ids);
    final byId = <String, Map<String, dynamic>>{
      for (final raw in profiles)
        if (raw['user_id'] is String)
          raw['user_id'] as String: Map<String, dynamic>.from(raw),
    };
    return [
      for (final raw in rows)
        if (byId['${raw['user_id']}'] != null)
          ?hostSeekerFromRow(
            requirement: Map<String, dynamic>.from(raw),
            profile: byId['${raw['user_id']}']!,
          ),
    ];
  }

  List<HostLiveSeeker> _parseRows(List<dynamic> rows) {
    return [
      for (final raw in rows)
        if (raw is Map)
          ?hostSeekerFromRow(
            requirement: Map<String, dynamic>.from(raw),
            profile: Map<String, dynamic>.from(raw),
          ),
    ];
  }

  HostSeekerFit? get _current {
    for (final fit in _fits) {
      if (!_gone.contains(fit.seeker.userId)) {
        return fit;
      }
    }
    return null;
  }

  Future<void> _like(HostSeekerFit fit) async {
    final id = fit.seeker.userId;
    if (isUuid(id)) {
      try {
        await Supabase.instance.client.rpc<dynamic>(
          'create_interest',
          params: interestParams(
            targetId: id,
            action: 'like',
            targetType: 'user',
          ),
        );
      } on Object {
        // The card still moves on. Interest can be sent again from the profile.
      }
    }
    setState(() => _gone.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Scaffold(
      key: const Key('host-match-deck'),
      backgroundColor: HomiziColors.white,
      appBar: const HomiziHomeBar(),
      body: _loading
          ? const LoadingState(message: 'Finding seekers…')
          : _error != null
          ? ErrorState(
              title: 'Seekers unavailable',
              message: _error!,
              onRetry: () => unawaited(_load()),
            )
          : current == null
          ? const EmptyState(
              key: Key('host-seekers-empty'),
              title: 'No seekers yet',
              message:
                  'When a tenant saves preferences that fit a home you published, they show up here.',
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: RoommateDeckCard(
                person: _person(current),
                percent: current.percent,
                viewerCity: current.listing.city,
                reasons: [
                  for (final factor in current.forward.factors)
                    if (factor.matched && factor.detail.trim().isNotEmpty)
                      factor.detail.trim(),
                ],
                onOpen: () => unawaited(
                  openProfileChat(
                    context,
                    ref,
                    otherUserId: current.seeker.userId,
                    name: current.seeker.name,
                    avatarUrl: current.seeker.photoRef,
                    listingId: current.listing.id,
                    listingTitle: current.listing.title,
                    place: current.listing.locality,
                    suggestGreeting: true,
                  ),
                ),
                onSkip: () => setState(() => _gone.add(current.seeker.userId)),
                onInterested: () => unawaited(_like(current)),
              ),
            ),
    );
  }
}

FinderPerson _person(HostSeekerFit fit) {
  final seeker = fit.seeker;
  final photo = (seeker.photoRef ?? '').trim();
  return FinderPerson(
    seeker: RoommateSeeker(
      id: seeker.userId,
      name: seeker.name,
      age: 0,
      profession: seeker.occupation,
      photoRef: photo.isEmpty ? null : photo,
      traits: RoommateTraits(
        city: seeker.city,
        localities: [
          if (seeker.locality.trim().isNotEmpty) seeker.locality.trim(),
        ],
        budgetMinInr: seeker.preferences.budgetMinInr,
        budgetMaxInr: seeker.preferences.budgetMaxInr,
        moveIn: seeker.preferences.moveIn,
      ),
      bio: seeker.occupation,
    ),
    group: seeker.occupation.trim().isEmpty ? 'Other' : seeker.occupation,
    field: seeker.occupation.trim().isEmpty ? 'Seeker' : seeker.occupation,
    drinking: '',
    lookingFor: '',
    education: '',
    hometown: '',
    about: seeker.occupation,
    gallery: [if (photo.isNotEmpty) photo],
  );
}

HostLiveSeeker? hostSeekerFromRow({
  required Map<String, dynamic> requirement,
  required Map<String, dynamic> profile,
}) {
  final id = (profile['user_id'] ?? requirement['user_id'])?.toString() ?? '';
  if (!isUuid(id)) {
    return null;
  }
  final city = _text(requirement['city']);
  final localities = _texts(requirement['localities']);
  final min = _money(requirement['budget_min_inr']);
  final max = _money(requirement['budget_max_inr']);
  final types = _texts(requirement['property_types']);
  final rooms = _texts(requirement['room_type']);
  final locality = localities.isEmpty ? '' : localities.first;
  final preferences = SeekerMatchInput(
    budgetMinInr: min,
    budgetMaxInr: max,
    city: city,
    localities: localities,
    propertyTypes: types,
    occupancy: rooms.contains('shared') || types.contains('shared_room')
        ? 'shared'
        : '',
    moveIn: DateTime.tryParse('${requirement['move_in_date']}'),
  );
  if (!preferences.isSpecified) {
    return null;
  }
  final budget = min == null && max == null
      ? 'Budget not set'
      : min != null && max != null
      ? '${formatInr(min)}–${formatInr(max)}'
      : max != null
      ? 'Up to ${formatInr(max)}'
      : 'From ${formatInr(min!)}';
  final midpoint = min != null && max != null
      ? ((min + max) / 2).round()
      : (max ?? min ?? 0);
  return HostLiveSeeker(
    userId: id,
    name: _text(profile['display_name'], fallback: 'Tenant'),
    occupation: _text(profile['occupation']),
    city: city,
    locality: locality,
    budgetLabel: budget,
    photoRef: _text(profile['avatar_path']),
    preferences: preferences,
    asSubject: MatchSubject(
      rentInr: midpoint,
      propertyType: types.isEmpty ? '' : types.first,
      bedrooms: 1,
      occupancyMax: rooms.contains('shared') ? 2 : 1,
      city: city,
      locality: locality,
    ),
  );
}

String _text(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || text == 'null' ? fallback : text;
}

List<String> _texts(Object? value) {
  if (value is List) {
    return [
      for (final item in value)
        if (item.toString().trim().isNotEmpty) item.toString().trim(),
    ];
  }
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null') {
    return const [];
  }
  return [text];
}

int? _money(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  final parsed = int.tryParse('$value');
  return parsed;
}
