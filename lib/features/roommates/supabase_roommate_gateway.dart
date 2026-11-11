import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/trust/user_badges.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRoommateGateway implements RoommateGateway {
  SupabaseRoommateGateway(this._client);

  final SupabaseClient _client;
  final Set<String> _liked = {};

  @override
  Future<List<RoommateSeeker>> load(RoommateQuery query) async {
    _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'list_roommate_seekers',
        params: {
          'p_locality': query.locality,
          'p_budget_min': query.budgetOpen ? null : query.budgetMinInr,
          'p_budget_max': query.budgetOpen ? null : query.budgetMaxInr,
          'p_gender': query.gender,
          'p_move_in_window': query.moveInWindow,
        },
      ),
    );
    final rows = _list(raw);
    return [for (final row in rows) _seeker(row)];
  }

  @override
  Future<RoommateScore> breakdown(RoommateSeeker seeker) async {
    final user = _requireUser();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'roommate_compatibility_breakdown',
        params: {'a': user.id, 'b': seeker.id},
      ),
    );
    if (raw is! Map) {
      throw const RoommateFailure('Compatibility did not load.');
    }
    return _score(Map<String, dynamic>.from(raw));
  }

  @override
  Future<String> like(RoommateSeeker seeker) async {
    return _interest(seeker, 'like');
  }

  @override
  Future<String> pass(RoommateSeeker seeker) async {
    return _interest(seeker, 'pass');
  }

  @override
  Future<List<RoommateSeeker>> mutual() async {
    final user = _requireUser();
    final liked = {..._liked};
    try {
      final rows = await _client
          .from('interests')
          .select('target_id')
          .eq('actor_user_id', user.id)
          .eq('target_type', 'user')
          .eq('action', 'like');
      for (final row in rows) {
        final id = row['target_id']?.toString() ?? '';
        if (id.isNotEmpty) {
          liked.add(id);
        }
      }
    } catch (error) {
      if (error is RoommateFailure) {
        rethrow;
      }
    }
    final people = await load(const RoommateQuery());
    return [
      for (final seeker in people)
        if (seeker.likesYou || liked.contains(seeker.id)) seeker,
    ];
  }

  @override
  Future<RoommateSeeker?> byId(String id) async {
    final people = await load(const RoommateQuery());
    for (final seeker in people) {
      if (seeker.id == id) {
        return seeker;
      }
    }
    return null;
  }

  Future<String> _interest(RoommateSeeker seeker, String action) async {
    _requireUser();
    if (action == 'like') {
      _liked.add(seeker.id);
    } else {
      _liked.remove(seeker.id);
    }
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'create_interest',
        params: interestParams(
          targetId: seeker.id,
          action: action,
          targetType: 'user',
        ),
      ),
    );
    final interest = parseInterestResponse(raw);
    if (!interest.ok) {
      throw RoommateFailure(interestErrorMessage(interest.error));
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
        params: mutualMatchParams(seeker.id),
      ),
    );
    final match = parseMutualMatchResponse(matchRaw);
    if (match.ok || match.matchId != null) {
      return DiscoveryCopy.serverMatched;
    }
    return DiscoveryCopy.serverLike;
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const RoommateFailure('Sign in before continuing.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } catch (error) {
      if (error is RoommateFailure) {
        rethrow;
      }
      throw RoommateFailure(describedFailure(error));
    }
  }
}

List<Map<String, dynamic>> _list(Object? raw) {
  if (raw is List) {
    return [
      for (final item in raw)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }
  return const [];
}

RoommateSeeker _seeker(Map<String, dynamic> row) {
  final aadhaar = _flag(row['aadhaar_verified']);
  final face = _flag(row['face_verified']);
  final verified = _flag(row['verified']);
  return RoommateSeeker(
    id: row['user_id']?.toString() ?? '',
    name: _text(row['display_name'], 'Roommate'),
    age: _int(row['age']) ?? 0,
    profession: _text(row['profession'], ''),
    photoRef: _photo(row['photo_url']?.toString()),
    likesYou: _flag(row['likes_you']),
    seekingRole: _text(row['seeking_role'], 'roommate'),
    score: _int(row['score']) ?? 0,
    trust: UserBadges(
      aadhaarVerified: aadhaar,
      faceVerified: face,
      profileComplete: verified && !aadhaar && !face,
    ),
    traits: RoommateTraits(
      city: _text(row['city'], ''),
      localities: [
        for (final item
            in (row['localities'] is List
                ? row['localities'] as List
                : const []))
          item.toString(),
      ],
      budgetMinInr: _int(row['budget_min_inr']),
      budgetMaxInr: _int(row['budget_max_inr']),
      moveIn: _date(row['move_in_date']),
      gender: _text(row['gender'], ''),
    ),
  );
}

RoommateScore _score(Map<String, dynamic> row) {
  final rawRows = row['rows'];
  final rawHighlights = row['highlights'];
  return RoommateScore(
    score: _int(row['score']) ?? 0,
    rows: [
      for (final item in (rawRows is List ? rawRows : const []))
        if (item is Map)
          RoommateScoreRow(
            key: _text(item['key'], ''),
            label: _text(item['label'], ''),
            ok: _flag(item['ok']),
            detail: _text(item['detail'], ''),
            points: _int(item['points']) ?? 0,
            maxPoints: _int(item['max']) ?? 0,
          ),
    ],
    highlights: [
      for (final item in (rawHighlights is List ? rawHighlights : const []))
        item.toString(),
    ],
  );
}

String? _photo(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _text(Object? value, String fallback) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return fallback;
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

bool _flag(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is String) {
    return value == 'true' || value == 't';
  }
  return false;
}

DateTime? _date(Object? value) {
  if (value is! String || value.length < 10) {
    return null;
  }
  return DateTime.tryParse(value.substring(0, 10));
}
