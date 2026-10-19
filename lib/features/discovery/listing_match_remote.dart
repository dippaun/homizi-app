import 'package:homizi/features/discovery/domain/listing_match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls `requirement_listing_match(listing_id, requirement_id)` when the
/// requirements work has deployed it. A missing function returns null so the
/// local engine keeps the badge and the breakdown.
abstract interface class ServerMatchClient {
  Future<ListingMatch?> requirementListingMatch({
    required String listingId,
    required String requirementId,
  });
}

class UnavailableServerMatchClient implements ServerMatchClient {
  const UnavailableServerMatchClient();

  @override
  Future<ListingMatch?> requirementListingMatch({
    required String listingId,
    required String requirementId,
  }) async {
    return null;
  }
}

class SupabaseServerMatchClient implements ServerMatchClient {
  const SupabaseServerMatchClient(this._client);

  final SupabaseClient _client;

  @override
  Future<ListingMatch?> requirementListingMatch({
    required String listingId,
    required String requirementId,
  }) async {
    if (!_uuid(listingId) || !_uuid(requirementId)) {
      return null;
    }
    try {
      final raw = await _client.rpc<dynamic>(
        'requirement_listing_match',
        params: {'listing_id': listingId, 'requirement_id': requirementId},
      );
      return listingMatchFromServer(raw);
    } catch (_) {
      return null;
    }
  }
}

bool _uuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
