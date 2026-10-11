// Checks in-app notifications against a local Supabase API.
// Usage:
//   SUPABASE_URL=... SUPABASE_ANON_KEY=... dart run tool/notification_check.dart
// The key is the local public client key. This script does not use the service role.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _payloadKeys = {'match_id', 'visit_id', 'conversation_id'};
const _forbiddenKeys = {
  'phone',
  'email',
  'address_line',
  'landmark',
  'latitude',
  'longitude',
  'street_address',
  'aadhaar',
  'body',
};
final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  if (url.isEmpty || anonKey.isEmpty) {
    stderr.writeln(
      'SUPABASE_URL and SUPABASE_ANON_KEY are required. '
      'Demo mode does not load server notifications.',
    );
    exitCode = 1;
    return;
  }

  final client = HttpClient();
  try {
    final host = await _session(client, url, anonKey, 'host');
    final tenant = await _session(client, url, anonKey, 'tenant');
    final stranger = await _session(client, url, anonKey, 'stranger');
    final propertyId = _uuidValue();
    final requirementId = _uuidValue();

    await _rest(client, url, anonKey, host.token, 'POST', 'properties', {
      'id': propertyId,
      'host_user_id': host.userId,
      'title': 'Notice home',
      'locality': 'Baner',
      'city': 'Pune',
      'address_visibility': 'locality_only',
      'property_type': 'apartment',
      'furnishing': 'semi_furnished',
      'rent_inr': 18000,
      'deposit_inr': 0,
      'occupancy_max': 1,
    });
    await _rest(client, url, anonKey, host.token, 'POST', 'property_photos', [
      for (var index = 0; index < 3; index++)
        {
          'property_id': propertyId,
          'storage_path': '${host.userId}/$propertyId/$index.slot',
          'sort_order': index,
          'photo_type': 'other',
        },
    ]);
    _expectOk(
      await _rpc(client, url, anonKey, host.token, 'publish_listing', {
        'p_property_id': propertyId,
      }),
      'publish_listing',
    );
    await _rest(
      client,
      url,
      anonKey,
      tenant.token,
      'POST',
      'listing_requirements',
      {
        'id': requirementId,
        'user_id': tenant.userId,
        'city': 'Pune',
        'localities': ['Baner'],
        'budget_min_inr': 10000,
        'budget_max_inr': 25000,
      },
    );
    _expectOk(
      await _rpc(client, url, anonKey, tenant.token, 'publish_requirement', {
        'p_requirement_id': requirementId,
      }),
      'publish_requirement',
    );
    await _rpc(client, url, anonKey, tenant.token, 'create_interest', {
      'p_target_type': 'property',
      'p_target_id': propertyId,
      'p_action': 'like',
    });
    final matched = await _rpc(
      client,
      url,
      anonKey,
      host.token,
      'create_interest',
      {
        'p_target_type': 'listing_requirement',
        'p_target_id': requirementId,
        'p_action': 'like',
      },
    );
    final match = matched['match'];
    if (match is! Map || match['match_id'] is! String) {
      throw StateError('A mutual like did not open a match.');
    }
    final matchId = match['match_id'] as String;

    final tenantNotes = await _notes(client, url, anonKey, tenant.token);
    final hostNotes = await _notes(client, url, anonKey, host.token);
    _expectClean(tenantNotes, 'tenant inbox');
    _expectClean(hostNotes, 'host inbox');
    if (!_hasType(tenantNotes, 'match') || !_hasType(hostNotes, 'match')) {
      throw StateError('A match did not notify both people.');
    }

    final opened = await _rpc(
      client,
      url,
      anonKey,
      tenant.token,
      'open_conversation',
      {'p_match_id': matchId},
    );
    final conversationId = opened['conversation_id'];
    if (conversationId is! String) {
      throw StateError('open_conversation did not return an id.');
    }
    await _rpc(client, url, anonKey, tenant.token, 'send_message', {
      'p_conversation_id': conversationId,
      'p_body': 'See you at 11',
    });
    final afterMessageTenant = await _notes(client, url, anonKey, tenant.token);
    final afterMessageHost = await _notes(client, url, anonKey, host.token);
    _expectClean(afterMessageHost, 'host inbox after a message');
    if (_hasType(afterMessageTenant, 'message')) {
      throw StateError('The sender was notified of their own message.');
    }
    if (!_hasType(afterMessageHost, 'message')) {
      throw StateError('The other person was not notified of the message.');
    }
    if (jsonEncode(afterMessageHost).contains('See you at 11')) {
      throw StateError('The message body was copied into a notification.');
    }

    final visit = await _rpc(
      client,
      url,
      anonKey,
      tenant.token,
      'request_visit',
      {
        'p_match_id': matchId,
        'p_slots': [
          {'starts_at': '2026-11-02T05:30:00Z'},
        ],
      },
    );
    final visitId = visit['visit_id'];
    if (visitId is! String) {
      throw StateError('request_visit did not return an id.');
    }
    final afterVisitHost = await _notes(client, url, anonKey, host.token);
    _expectClean(afterVisitHost, 'host inbox after a visit');
    if (!_hasType(afterVisitHost, 'visit_requested')) {
      throw StateError('The other person was not notified of the visit.');
    }
    await _rpc(client, url, anonKey, host.token, 'respond_visit', {
      'p_visit_id': visitId,
      'p_status': 'accepted',
    });
    final afterAcceptTenant = await _notes(client, url, anonKey, tenant.token);
    _expectClean(afterAcceptTenant, 'tenant inbox after an accepted visit');
    if (!_hasType(afterAcceptTenant, 'visit_accepted')) {
      throw StateError(
        'The requester was not notified that the visit was accepted.',
      );
    }

    final matchNotice = tenantNotes.cast<Map<String, dynamic>>().firstWhere(
      (row) => row['type'] == 'match',
    );
    final noticeId = matchNotice['id'];
    if (noticeId is! String) {
      throw StateError('A match notification had no id.');
    }
    final marked = jsonDecode(
      await _rest(
        client,
        url,
        anonKey,
        tenant.token,
        'PATCH',
        'notifications?id=eq.$noticeId',
        {'read_at': '2026-10-11T12:00:00.000Z'},
      ),
    );
    if (marked is! List || marked.isEmpty || marked.first is! Map) {
      throw StateError('Marking a notification read did not return the row.');
    }
    if ((marked.first as Map)['read_at'] == null) {
      throw StateError('read_at was not stored.');
    }
    _expectClean(marked, 'marked notification');

    final deniedType = await _send(
      client,
      'PATCH',
      '$url/rest/v1/notifications?id=eq.$noticeId',
      anonKey,
      token: tenant.token,
      contentType: 'application/json',
      body: utf8.encode(jsonEncode({'type': 'message'})),
    );
    if (deniedType.statusCode < 400) {
      throw StateError('The client was allowed to change a notification type.');
    }

    final strangerNotes = jsonDecode(
      await _rest(
        client,
        url,
        anonKey,
        stranger.token,
        'GET',
        'notifications?select=id,type,payload_minimal,read_at',
        null,
      ),
    );
    if (strangerNotes is! List || strangerNotes.isNotEmpty) {
      throw StateError('A stranger could read notifications.');
    }

    final inserted = await _send(
      client,
      'POST',
      '$url/rest/v1/notifications',
      anonKey,
      token: tenant.token,
      contentType: 'application/json',
      body: utf8.encode(
        jsonEncode({
          'user_id': tenant.userId,
          'type': 'match',
          'payload_minimal': {'match_id': matchId},
        }),
      ),
    );
    if (inserted.statusCode < 400) {
      throw StateError('The client was allowed to insert a notification.');
    }

    stdout.writeln('notification check passed');
  } finally {
    client.close(force: true);
  }
}

bool _hasType(List<dynamic> rows, String type) {
  return rows.any((row) => row is Map && row['type'] == type);
}

void _expectClean(Object? body, String label) {
  final encoded = jsonEncode(body);
  if (encoded.contains('@')) {
    throw StateError('$label included an email-like value.');
  }
  if (body is! List) {
    return;
  }
  for (final row in body) {
    if (row is! Map) {
      throw StateError('$label had a row that was not an object.');
    }
    final payload = row['payload_minimal'];
    if (payload is! Map) {
      throw StateError('$label was missing payload_minimal.');
    }
    for (final key in payload.keys) {
      final name = key.toString();
      if (_forbiddenKeys.contains(name) || !_payloadKeys.contains(name)) {
        throw StateError('$label included $name.');
      }
      final value = payload[key];
      if (value is! String || !_uuid.hasMatch(value)) {
        throw StateError('$label had a payload value that was not an id.');
      }
    }
    if (payload['match_id'] is! String) {
      throw StateError('$label was missing match_id.');
    }
  }
}

class _Session {
  const _Session(this.token, this.userId);

  final String token;
  final String userId;
}

class _Reply {
  const _Reply(this.statusCode, this.body);

  final int statusCode;
  final String body;
}

Future<List<dynamic>> _notes(
  HttpClient client,
  String url,
  String anonKey,
  String token,
) async {
  final body = jsonDecode(
    await _rest(
      client,
      url,
      anonKey,
      token,
      'GET',
      'notifications?select=id,type,payload_minimal,read_at,created_at&order=created_at.desc',
      null,
    ),
  );
  if (body is! List) {
    throw StateError('The notification list was not a list.');
  }
  return body;
}

Future<_Session> _session(
  HttpClient client,
  String url,
  String anonKey,
  String label,
) async {
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final response = await _send(
    client,
    'POST',
    '$url/auth/v1/signup',
    anonKey,
    contentType: 'application/json',
    body: utf8.encode(
      jsonEncode({
        'email': 'note-$label-$stamp@example.test',
        'password': 'local-note-check-1',
      }),
    ),
  );
  if (response.statusCode >= 400) {
    throw StateError('Sign-up failed for $label (${response.statusCode}).');
  }
  final body = jsonDecode(response.body);
  if (body is! Map || body['access_token'] is! String) {
    throw StateError('Sign-up did not return a session for $label.');
  }
  final user = body['user'];
  if (user is! Map || user['id'] is! String) {
    throw StateError('Sign-up did not return a user id for $label.');
  }
  return _Session(body['access_token'] as String, user['id'] as String);
}

Future<Map<String, dynamic>> _rpc(
  HttpClient client,
  String url,
  String anonKey,
  String token,
  String name,
  Map<String, dynamic> params,
) async {
  final response = await _send(
    client,
    'POST',
    '$url/rest/v1/rpc/$name',
    anonKey,
    token: token,
    contentType: 'application/json',
    body: utf8.encode(jsonEncode(params)),
  );
  if (response.statusCode >= 400) {
    throw StateError('$name failed (${response.statusCode}).');
  }
  final body = jsonDecode(response.body);
  if (body is! Map) {
    throw StateError('$name did not return an object.');
  }
  return body.map((key, value) => MapEntry(key.toString(), value));
}

void _expectOk(Map<String, dynamic> body, String label) {
  if (body['ok'] != true) {
    throw StateError('$label was not accepted.');
  }
}

Future<String> _rest(
  HttpClient client,
  String url,
  String anonKey,
  String token,
  String method,
  String pathAndQuery,
  Object? jsonBody,
) async {
  final response = await _send(
    client,
    method,
    '$url/rest/v1/$pathAndQuery',
    anonKey,
    token: token,
    contentType: jsonBody == null ? null : 'application/json',
    body: jsonBody == null ? null : utf8.encode(jsonEncode(jsonBody)),
    headers: {'Prefer': 'return=representation'},
  );
  if (response.statusCode >= 400) {
    throw StateError('$method $pathAndQuery failed (${response.statusCode}).');
  }
  return response.body;
}

Future<_Reply> _send(
  HttpClient client,
  String method,
  String url,
  String anonKey, {
  String? token,
  String? contentType,
  List<int>? body,
  Map<String, String> headers = const {},
}) async {
  final request = await client.openUrl(method, Uri.parse(url));
  request.headers.set('apikey', anonKey);
  if (token != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  }
  if (contentType != null) {
    request.headers.set(HttpHeaders.contentTypeHeader, contentType);
  }
  for (final entry in headers.entries) {
    request.headers.set(entry.key, entry.value);
  }
  if (body != null) {
    request.add(body);
  }
  final response = await request.close();
  final bytes = await response.fold<List<int>>(<int>[], (collected, chunk) {
    collected.addAll(chunk);
    return collected;
  });
  return _Reply(response.statusCode, utf8.decode(bytes, allowMalformed: true));
}

String _uuidValue() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
