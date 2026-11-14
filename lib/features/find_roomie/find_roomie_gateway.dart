import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/find_roomie/find_roomie_catalog.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';
import 'package:homizi/features/roommates/demo_catalog.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/domain/roommate_traits.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// People and pair rows for Find Your Roomie.
///
/// Seekers and the match UUID come from the existing RPCs
/// `list_roommate_seekers`, `create_interest`, and `create_mutual_match`.
/// Shortlists and joint requests use the new tables. Every failure returns
/// sample data or `false` / `null` so the screen never shows an error string.
abstract interface class FindRoomieGateway {
  Future<FindRoomieDeck> loadSeekers();

  Future<FindRoomieConnect> connect(RoommateSeeker person);

  Future<bool> saveShortlist(FindRoomieShortlist row);

  /// Null when the table is missing or nobody is signed in.
  Future<List<FindRoomieShortlist>?> shortlists();

  Future<bool> saveJoint(FindRoomieJoint row);

  Future<List<FindRoomieJoint>?> joints();
}

class SampleFindRoomieGateway implements FindRoomieGateway {
  const SampleFindRoomieGateway();

  @override
  Future<FindRoomieDeck> loadSeekers() async => sampleFindRoomieDeck();

  @override
  Future<FindRoomieConnect> connect(RoommateSeeker person) async {
    return FindRoomieConnect(
      matchId: sampleMatchId(person.id),
      fromServer: false,
    );
  }

  @override
  Future<bool> saveShortlist(FindRoomieShortlist row) async => false;

  @override
  Future<List<FindRoomieShortlist>?> shortlists() async => null;

  @override
  Future<bool> saveJoint(FindRoomieJoint row) async => false;

  @override
  Future<List<FindRoomieJoint>?> joints() async => null;
}

class SupabaseFindRoomieGateway implements FindRoomieGateway {
  SupabaseFindRoomieGateway(this._client);

  final SupabaseClient _client;

  String? get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      return null;
    }
    return id;
  }

  @override
  Future<FindRoomieDeck> loadSeekers() async {
    final userId = _userId;
    if (userId == null) {
      return resolveDeck(
        signedIn: false,
        failed: false,
        raw: null,
        viewer: demoViewerTraits,
        viewerId: '',
        viewerFirstName: findRoomieViewerFirstName,
        sample: sampleFindRoomieDeck(),
      );
    }
    try {
      final raw = await _client.rpc<dynamic>(
        'list_roommate_seekers',
        params: const {
          'p_locality': null,
          'p_budget_min': null,
          'p_budget_max': null,
          'p_gender': null,
          'p_move_in_window': null,
        },
      );
      final viewer = await _viewer(userId);
      return resolveDeck(
        signedIn: true,
        failed: false,
        raw: raw,
        viewer: viewer.traits,
        viewerId: userId,
        viewerFirstName: viewer.firstName,
        sample: sampleFindRoomieDeck(),
      );
    } on Object {
      return sampleFindRoomieDeck();
    }
  }

  @override
  Future<FindRoomieConnect> connect(RoommateSeeker person) async {
    if (_userId == null || !findRoomieIsUuid(person.id)) {
      return resolveConnect(
        personId: person.id,
        signedIn: false,
        failed: false,
      );
    }
    try {
      final interestRaw = await _client.rpc<dynamic>(
        'create_interest',
        params: interestParams(
          targetId: person.id,
          action: 'like',
          targetType: 'user',
        ),
      );
      final interest = parseInterestResponse(interestRaw);
      Object? mutualRaw;
      if (interest.matchId == null || interest.matchId!.isEmpty) {
        mutualRaw = await _client.rpc<dynamic>(
          'create_mutual_match',
          params: mutualMatchParams(person.id),
        );
      }
      return resolveConnect(
        personId: person.id,
        signedIn: true,
        failed: false,
        interestRaw: interestRaw,
        mutualRaw: mutualRaw,
      );
    } on Object {
      return resolveConnect(personId: person.id, signedIn: true, failed: true);
    }
  }

  @override
  Future<bool> saveShortlist(FindRoomieShortlist row) async {
    if (!_pairCanWrite(row.memberA, row.memberB)) {
      return false;
    }
    try {
      final existing = await _client
          .from('roommate_shortlists')
          .select('id')
          .eq('member_a', row.memberA)
          .eq('member_b', row.memberB)
          .eq('listing_id', row.listingId)
          .maybeSingle();
      if (existing != null) {
        return true;
      }
      await _client.from('roommate_shortlists').insert({
        'member_a': row.memberA,
        'member_b': row.memberB,
        'listing_id': row.listingId,
        'created_by': _userId,
        if (_serverMatch(row.matchId) != null) 'match_id': row.matchId,
      });
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<List<FindRoomieShortlist>?> shortlists() async {
    final userId = _userId;
    if (userId == null) {
      return null;
    }
    try {
      final rows = await _client
          .from('roommate_shortlists')
          .select('member_a, member_b, listing_id, match_id')
          .or('member_a.eq.$userId,member_b.eq.$userId');
      return [
        for (final row in rows)
          FindRoomieShortlist(
            memberA: '${row['member_a']}',
            memberB: '${row['member_b']}',
            listingId: '${row['listing_id']}',
            matchId: _optional('${row['match_id']}'),
          ),
      ];
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> saveJoint(FindRoomieJoint row) async {
    final userId = _userId;
    if (userId == null || !_pairCanWrite(row.memberA, row.memberB)) {
      return false;
    }
    final mine = userId == row.memberA;
    final patch = <String, Object>{
      if (mine) 'member_a_confirmed': row.aConfirmed,
      if (!mine) 'member_b_confirmed': row.bConfirmed,
    };
    try {
      final updated = await _client
          .from('roommate_joint_requests')
          .update(patch)
          .eq('member_a', row.memberA)
          .eq('member_b', row.memberB)
          .eq('listing_id', row.listingId)
          .select('id');
      if (updated.isNotEmpty) {
        return true;
      }
      await _client.from('roommate_joint_requests').insert({
        'member_a': row.memberA,
        'member_b': row.memberB,
        'listing_id': row.listingId,
        'created_by': userId,
        'member_a_confirmed': mine && row.aConfirmed,
        'member_b_confirmed': !mine && row.bConfirmed,
        if (_serverMatch(row.matchId) != null) 'match_id': row.matchId,
      });
      return true;
    } on Object {
      return false;
    }
  }

  @override
  Future<List<FindRoomieJoint>?> joints() async {
    final userId = _userId;
    if (userId == null) {
      return null;
    }
    try {
      final rows = await _client
          .from('roommate_joint_requests')
          .select(
            'member_a, member_b, listing_id, match_id, '
            'member_a_confirmed, member_b_confirmed',
          )
          .or('member_a.eq.$userId,member_b.eq.$userId');
      return [
        for (final row in rows)
          FindRoomieJoint(
            memberA: '${row['member_a']}',
            memberB: '${row['member_b']}',
            listingId: '${row['listing_id']}',
            matchId: _optional('${row['match_id']}'),
            aConfirmed: row['member_a_confirmed'] == true,
            bConfirmed: row['member_b_confirmed'] == true,
          ),
      ];
    } on Object {
      return null;
    }
  }

  bool _pairCanWrite(String memberA, String memberB) {
    final userId = _userId;
    if (userId == null) {
      return false;
    }
    if (!findRoomieIsUuid(memberA) || !findRoomieIsUuid(memberB)) {
      return false;
    }
    return userId == memberA || userId == memberB;
  }

  String? _serverMatch(String? matchId) {
    if (matchId == null || !findRoomieIsUuid(matchId)) {
      return null;
    }
    return matchId;
  }

  String? _optional(String value) {
    if (value.isEmpty || value == 'null') {
      return null;
    }
    return value;
  }

  Future<({RoommateTraits traits, String firstName})> _viewer(
    String userId,
  ) async {
    try {
      final profile = await _client
          .from('roommate_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      final nameRow = await _client
          .from('profiles')
          .select('display_name')
          .eq('user_id', userId)
          .maybeSingle();
      final traits = profile == null
          ? demoViewerTraits
          : traitsFromProfileRow(Map<String, dynamic>.from(profile));
      final rawName = nameRow?['display_name']?.toString() ?? '';
      final first = rawName.trim().isEmpty
          ? findRoomieViewerFirstName
          : findRoomieFirstName(rawName);
      return (traits: traits, firstName: first);
    } on Object {
      return (traits: demoViewerTraits, firstName: findRoomieViewerFirstName);
    }
  }
}
