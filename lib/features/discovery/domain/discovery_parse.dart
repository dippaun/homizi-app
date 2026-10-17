import 'package:homizi/features/discovery/domain/listing.dart';

const interestRpcParams = <String>['p_target_type', 'p_target_id', 'p_action'];

const mutualMatchRpcParams = <String>['p_other_user_id'];

const contactVisibilityRpcParams = <String>['p_match_id'];

const grantConsentRpcParams = <String>['p_match_id', 'p_scope'];

const revokeConsentRpcParams = <String>['p_match_id'];

const contactShareScopes = <String>['phone', 'email', 'phone_and_email'];

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

String? normalizeContactScope(Object? raw) {
  if (raw is! String) {
    return null;
  }
  final scope = raw.trim().toLowerCase();
  if (contactShareScopes.contains(scope)) {
    return scope;
  }
  return null;
}

Map<String, dynamic> grantContactConsentParams({
  required String matchId,
  required String scope,
}) {
  return {'p_match_id': matchId, 'p_scope': scope};
}

Map<String, dynamic> revokeContactConsentParams(String matchId) {
  return {'p_match_id': matchId};
}

class ConsentRpcResult {
  const ConsentRpcResult({required this.ok, this.error});

  final bool ok;
  final String? error;
}

ConsentRpcResult parseConsentResponse(Object? raw) {
  final body = _map(raw);
  if (body == null || body['ok'] != true) {
    return ConsentRpcResult(ok: false, error: _string(body?['error']));
  }
  return const ConsentRpcResult(ok: true);
}

String consentErrorMessage(String? code) {
  switch (code) {
    case 'unauthenticated':
      return 'Sign in before sharing contact.';
    case 'not_participant':
      return 'You can only share contact on an active match.';
    case 'blocked':
      return 'Contact stays hidden because one of you blocked the other.';
    default:
      return 'The server did not update your contact share.';
  }
}

/// Own share scopes only. Another person's row, and any phone or email
/// stuffed into the payload, are ignored.
Map<String, String> ownSharesFromConsentRows(
  List<Map<String, dynamic>> rows,
  String userId,
) {
  final shares = <String, String>{};
  for (final row in rows) {
    if (row['granted_by'] != userId || row['revoked_at'] != null) {
      continue;
    }
    final matchId = row['match_id'];
    final scope = normalizeContactScope(row['scope']);
    if (matchId is String && scope != null) {
      shares[matchId] = scope;
    }
  }
  return shares;
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

/// Columns the explore feed may select. Street address and contact stay out.
const publicListingColumns = <String>[
  'id',
  'host_user_id',
  'title',
  'locality',
  'city',
  'rent_inr',
  'deposit_inr',
  'maintenance_inr',
  'brokerage_inr',
  'furnishing',
  'property_type',
  'occupancy_max',
  'available_from',
  'published_at',
];

const privateListingKeys = <String>{
  'phone',
  'email',
  'address_line',
  'landmark',
  'latitude',
  'longitude',
  'aadhaar',
  'date_of_birth',
};

/// Public card fields only. Street address and contact columns are ignored.
Listing listingFromPropertyRow(
  Map<String, dynamic> row, {
  required String hostName,
  List<Map<String, dynamic>> features = const [],
}) {
  final grouped = _featureGroups(features);
  final bedrooms = int.tryParse(grouped.bedrooms ?? '');
  return Listing(
    id: _string(row['id']) ?? '',
    hostUserId: _string(row['host_user_id']) ?? '',
    title: _string(row['title']) ?? 'Home',
    city: _string(row['city']) ?? '',
    locality: _string(row['locality']) ?? '',
    rentInr: _asInt(row['rent_inr']),
    depositInr: _asInt(row['deposit_inr']),
    maintenanceInr: _asInt(row['maintenance_inr']),
    brokerageInr: _asInt(row['brokerage_inr']),
    occupancyMax: _occupancy(row['occupancy_max']),
    availableFromIso: _isoDate(row['available_from']),
    furnishing: _string(row['furnishing']) ?? 'semi_furnished',
    propertyType: _string(row['property_type']) ?? 'apartment',
    hostDisplayName: hostName.trim().isEmpty ? 'Host' : hostName.trim(),
    amenities: grouped.amenities,
    restrictions: grouped.restrictions,
    suitability: grouped.suitability,
    bedrooms: bedrooms ?? _defaultBedrooms(_string(row['property_type'])),
    summary:
        'Published home. The street address and contact details are not on this card.',
  );
}

class PreciseAddress {
  const PreciseAddress.hidden()
    : revealed = false,
      line = null,
      landmark = null;

  const PreciseAddress.revealed({required this.line, this.landmark})
    : revealed = true;

  final bool revealed;
  final String? line;
  final String? landmark;

  bool get showsLine => revealed && line != null && line!.trim().isNotEmpty;
}

/// Address text is kept only when the server says the visit gate is open.
PreciseAddress parsePreciseAddress(Object? raw) {
  final body = _map(raw);
  if (body == null || body['revealed'] != true || body['ok'] == false) {
    return const PreciseAddress.hidden();
  }
  final line = _string(body['address_line'])?.trim();
  if (line == null || line.isEmpty) {
    return const PreciseAddress.hidden();
  }
  final landmark = _string(body['landmark'])?.trim();
  return PreciseAddress.revealed(
    line: line,
    landmark: landmark == null || landmark.isEmpty ? null : landmark,
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

class _FeatureGroups {
  const _FeatureGroups({
    required this.amenities,
    required this.restrictions,
    required this.suitability,
    this.bedrooms,
  });

  final List<String> amenities;
  final List<String> restrictions;
  final List<String> suitability;
  final String? bedrooms;
}

_FeatureGroups _featureGroups(List<Map<String, dynamic>> features) {
  final amenities = <String>[];
  final restrictions = <String>[];
  final suitability = <String>[];
  String? bedrooms;
  for (final row in features) {
    final key = _string(row['feature_key']) ?? '';
    final value = _string(row['value']) ?? '';
    if (key == 'bedrooms') {
      bedrooms = value;
    } else if (key.startsWith('amenity:')) {
      amenities.add(_featureLabel(key.substring('amenity:'.length)));
    } else if (key.startsWith('restriction:')) {
      restrictions.add(_featureLabel(key.substring('restriction:'.length)));
    } else if (key.startsWith('suitability:')) {
      suitability.add(_featureLabel(key.substring('suitability:'.length)));
    }
  }
  return _FeatureGroups(
    amenities: amenities,
    restrictions: restrictions,
    suitability: suitability,
    bedrooms: bedrooms,
  );
}

String _featureLabel(String key) => switch (key) {
  'lift' => 'Lift',
  'power_backup' => 'Power backup',
  'parking' => 'Parking',
  'wifi' => 'Wifi',
  'washing_machine' => 'Washing machine',
  'water_purifier' => 'Water purifier',
  'balcony' => 'Balcony',
  'security' => 'Security',
  'gym' => 'Gym',
  'wardrobes' => 'Wardrobes',
  'no_pets' => 'No pets',
  'no_smoking' => 'No smoking',
  'no_parties' => 'No loud parties',
  'family' => 'Family',
  'working_professionals' => 'Working professionals',
  'students' => 'Students',
  'couple' => 'Couple',
  _ => key,
};

int _defaultBedrooms(String? propertyType) {
  return switch (propertyType) {
    'studio' => 0,
    'shared_room' || 'private_room' => 1,
    _ => 2,
  };
}

int _occupancy(Object? value) {
  final amount = _asInt(value);
  if (amount < 1) {
    return 1;
  }
  return amount;
}

String? _isoDate(Object? value) {
  final text = _string(value);
  if (text == null || text.length < 10) {
    return null;
  }
  return text.substring(0, 10);
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}
