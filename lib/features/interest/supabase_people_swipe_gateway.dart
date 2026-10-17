import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/interest/people_swipe_gateway.dart';
import 'package:homizi/features/interest/tenant_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabasePeopleSwipeGateway implements PeopleSwipeGateway {
  SupabasePeopleSwipeGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TenantCard>> load() async {
    final user = _requireUser();
    final requirements = await _guard(
      () => _client
          .from('listing_requirements')
          .select(
            'user_id, city, budget_min_inr, budget_max_inr, move_in_date, lifestyle',
          )
          .eq('status', 'published')
          .neq('user_id', user.id),
    );
    final ids = <String>[
      for (final raw in requirements)
        if (_map(raw)['user_id'] is String) _map(raw)['user_id'] as String,
    ];
    if (ids.isEmpty) {
      return const [];
    }
    final profiles = await _guard(
      () => _client
          .from('profiles')
          .select(
            'user_id, display_name, occupation, public_bio, avatar_path, age_range',
          )
          .inFilter('user_id', ids),
    );
    final byId = <String, Map<String, dynamic>>{
      for (final raw in profiles)
        if (_map(raw)['user_id'] is String)
          _map(raw)['user_id'] as String: _map(raw),
    };
    final cards = <TenantCard>[];
    final seen = <String>{};
    for (final raw in requirements) {
      final row = _map(raw);
      final id = row['user_id'];
      if (id is! String || !seen.add(id)) {
        continue;
      }
      final profile = byId[id];
      if (profile == null) {
        continue;
      }
      final avatar = profile['avatar_path'];
      final shown = Map<String, dynamic>.from(profile);
      if (avatar is String && avatar.trim().isNotEmpty) {
        shown['avatar_path'] = _publicAvatar(avatar);
      }
      cards.add(tenantCardFromRows(profile: shown, requirement: row));
    }
    return cards;
  }

  @override
  Future<String> like(TenantCard card) async {
    return _interest(card, 'like');
  }

  @override
  Future<String> pass(TenantCard card) async {
    return _interest(card, 'pass');
  }

  Future<String> _interest(TenantCard card, String action) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'create_interest',
        params: interestParams(
          targetId: card.userId,
          action: action,
          targetType: 'user',
        ),
      ),
    );
    final interest = parseInterestResponse(raw);
    if (!interest.ok) {
      throw PeopleSwipeFailure(interestErrorMessage(interest.error));
    }
    if (action == 'pass') {
      return DiscoveryCopy.serverPass;
    }
    if (interest.matchId != null) {
      return DiscoveryCopy.serverMatched;
    }
    final matchRaw = await _guard(
      () => _client.rpc<dynamic>(
        'create_mutual_match',
        params: mutualMatchParams(card.userId),
      ),
    );
    final match = parseMutualMatchResponse(matchRaw);
    if (match.ok || match.matchId != null) {
      return DiscoveryCopy.serverMatched;
    }
    return DiscoveryCopy.serverLike;
  }

  @override
  Future<String> undo(TenantCard card) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'undo_last_interest',
        params: {'p_target_type': 'user', 'p_target_id': card.userId},
      ),
    );
    final body = parseInterestResponse(raw);
    if (!body.ok) {
      throw PeopleSwipeFailure(interestErrorMessage(body.error));
    }
    return 'Last swipe undone.';
  }

  String _publicAvatar(String path) {
    final trimmed = path.trim();
    if (photoKind(trimmed) != PhotoKind.empty) {
      return trimmed;
    }
    return _client.storage.from('avatars').getPublicUrl(trimmed);
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const PeopleSwipeFailure('Sign in to review people.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PeopleSwipeFailure {
      rethrow;
    } catch (error) {
      throw PeopleSwipeFailure(describedFailure(error));
    }
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}
