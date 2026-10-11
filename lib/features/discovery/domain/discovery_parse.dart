import 'package:homizi/features/discovery/domain/listing.dart';

const interestRpcParams = <String>['p_target_type', 'p_target_id', 'p_action'];

const mutualMatchRpcParams = <String>['p_other_user_id'];

const contactVisibilityRpcParams = <String>['p_match_id'];

Map<String, dynamic> interestParams({
  required String targetId,
  required String action,
}) {
  return {
    'p_target_type': 'property',
    'p_target_id': targetId,
    'p_action': action,
  };
}

Map<String, dynamic> mutualMatchParams(String otherUserId) {
  return {'p_other_user_id': otherUserId};
}

Map<String, dynamic> contactVisibilityParams(String matchId) {
  return {'p_match_id': matchId};
}

class InterestRpcResult {
  const InterestRpcResult({required this.ok, this.error, this.matchId});

  final bool ok;
  final String? error;
  final String? matchId;
}

class MutualMatchRpcResult {
  const MutualMatchRpcResult({required this.ok, this.error, this.matchId});

  final bool ok;
  final String? error;
  final String? matchId;
}

InterestRpcResult parseInterestResponse(Object? raw) {
  final body = _map(raw);
  if (body == null || body['ok'] != true) {
    return InterestRpcResult(ok: false, error: _string(body?['error']));
  }
  final match = body['match'];
  String? matchId;
  if (match is Map && match['ok'] == true) {
    matchId = _string(match['match_id']);
  }
  return InterestRpcResult(ok: true, matchId: matchId);
}

MutualMatchRpcResult parseMutualMatchResponse(Object? raw) {
  final body = _map(raw);
  if (body == null || body['ok'] != true) {
    return MutualMatchRpcResult(ok: false, error: _string(body?['error']));
  }
  return MutualMatchRpcResult(ok: true, matchId: _string(body['match_id']));
}

String interestErrorMessage(String? code) {
  switch (code) {
    case 'unauthenticated':
      return 'Sign in before continuing.';
    case 'not_found':
      return 'That listing is not available.';
    case 'not_visible':
      return 'That listing is not published.';
    case 'self':
      return 'You cannot like your own listing.';
    case 'blocked':
      return 'This person is blocked.';
    case 'rate_limited':
      return 'Too many actions. Try again in a little while.';
    default:
      return 'The server did not record that action.';
  }
}

/// Public card fields only. Street address and contact columns are ignored.
Listing listingFromPropertyRow(
  Map<String, dynamic> row, {
  required String hostName,
}) {
  return Listing(
    id: _string(row['id']) ?? '',
    hostUserId: _string(row['host_user_id']) ?? '',
    title: _string(row['title']) ?? 'Home',
    city: _string(row['city']) ?? '',
    locality: _string(row['locality']) ?? '',
    rentInr: _asInt(row['rent_inr']),
    depositInr: _asInt(row['deposit_inr']),
    furnishing: _string(row['furnishing']) ?? 'semi_furnished',
    propertyType: _string(row['property_type']) ?? 'apartment',
    hostDisplayName: hostName.trim().isEmpty ? 'Host' : hostName.trim(),
    amenities: const [],
    summary: 'Published home. The street address and contact details are not on this card.',
  );
}

Map<String, dynamic>? _map(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

String? _string(Object? value) => value is String ? value : null;

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}
