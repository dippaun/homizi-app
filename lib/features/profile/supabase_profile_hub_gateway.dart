import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfileHubGateway implements ProfileHubGateway {
  SupabaseProfileHubGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<ProfileActivity> loadActivity() async {
    if (_client.auth.currentUser == null) {
      throw const ProfileHubFailure('Sign in before opening your profile.');
    }
    try {
      final raw = await _client.rpc<dynamic>('profile_activity');
      final activity = profileActivityFromJson(raw);
      final visits = await _visitRows();
      if (visits == null) {
        return activity;
      }
      return ProfileActivity(
        savedCount: activity.savedCount,
        viewedAvailable: activity.viewedAvailable,
        viewedCount: activity.viewedCount,
        requestCount: activity.requestCount,
        visitCount: visits.length,
        matchCount: activity.matchCount,
        saved: activity.saved,
        viewed: activity.viewed,
        requests: activity.requests,
        visits: visits,
        matches: activity.matches,
      );
    } on ProfileHubFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw ProfileHubFailure(_safe(error.message));
    } catch (error) {
      throw ProfileHubFailure(describedFailure(error));
    }
  }

  Future<List<ActivityVisit>?> _visitRows() async {
    try {
      final visitRows = await _client
          .from('visit_requests')
          .select('id, match_id, status, created_at')
          .order('created_at', ascending: false)
          .limit(20);
      final visits = <Map<String, dynamic>>[
        for (final raw in visitRows) _row(raw),
      ];
      final matchIds = <String>[
        for (final row in visits)
          if (row['match_id'] is String) row['match_id'] as String,
      ];
      final matchRows = matchIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : [
              for (final raw
                  in await _client
                      .from('matches')
                      .select('id, participant_a, participant_b')
                      .inFilter('id', matchIds))
                _row(raw),
            ];
      final userId = _client.auth.currentUser?.id;
      final otherByMatch = <String, String>{};
      for (final row in matchRows) {
        final id = row['id'];
        final first = row['participant_a'];
        final second = row['participant_b'];
        if (id is! String || first is! String || second is! String) {
          continue;
        }
        if (userId == null) {
          continue;
        }
        otherByMatch[id] = first == userId ? second : first;
      }
      final hosts = otherByMatch.values.toSet().toList();
      final propertyRows = hosts.isEmpty
          ? const <Map<String, dynamic>>[]
          : [
              for (final raw
                  in await _client
                      .from('properties')
                      .select('id, host_user_id, title')
                      .inFilter('host_user_id', hosts)
                      .eq('status', 'published'))
                _row(raw),
            ];
      final listingByHost = <String, Map<String, dynamic>>{};
      for (final row in propertyRows) {
        final host = row['host_user_id'];
        if (host is String && !listingByHost.containsKey(host)) {
          listingByHost[host] = row;
        }
      }
      return [
        for (final row in visits) _visitFrom(row, otherByMatch, listingByHost),
      ];
    } catch (_) {
      return null;
    }
  }
}

ActivityVisit _visitFrom(
  Map<String, dynamic> row,
  Map<String, String> otherByMatch,
  Map<String, Map<String, dynamic>> listingByHost,
) {
  final matchId = row['match_id'] is String ? row['match_id'] as String : null;
  final host = matchId == null ? null : otherByMatch[matchId];
  final listing = host == null ? null : listingByHost[host];
  final listingId = listing?['id'];
  final title = listing?['title'];
  return ActivityVisit(
    status: row['status'] is String ? row['status'] as String : 'requested',
    onIso: _day(row['created_at']),
    visitId: row['id'] is String ? row['id'] as String : null,
    matchId: matchId,
    listingId: listingId is String ? listingId : null,
    listingTitle: title is String && title.trim().isNotEmpty
        ? title.trim()
        : null,
  );
}

String _day(Object? raw) {
  final text = raw?.toString() ?? '';
  if (text.length >= 10) {
    return text.substring(0, 10);
  }
  return text;
}

Map<String, dynamic> _row(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return const {};
}

String _safe(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty ||
      trimmed.length > 180 ||
      trimmed.contains('@') ||
      trimmed.contains('+91')) {
    return 'Profile activity could not be loaded.';
  }
  return trimmed;
}
