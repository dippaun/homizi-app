// Checks chat and visit functions against a local Supabase API.
// Usage:
//   SUPABASE_URL=... SUPABASE_ANON_KEY=... dart run tool/chat_visit_check.dart
// The key is the local public client key. This script does not use the service role.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  if (url.isEmpty || anonKey.isEmpty) {
    stderr.writeln(
      'SUPABASE_URL and SUPABASE_ANON_KEY are required. '
      'Demo mode does not send chat.',
    );
    exitCode = 1;
    return;
  }

  final client = HttpClient();
  try {
    final host = await _session(client, url, anonKey, 'host');
    final tenant = await _session(client, url, anonKey, 'tenant');
    final stranger = await _session(client, url, anonKey, 'stranger');
    final propertyId = _uuid();
    final requirementId = _uuid();

    await _rest(client, url, anonKey, host.token, 'POST', 'properties', {
      'id': propertyId,
      'host_user_id': host.userId,
      'title': 'Chat home',
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
    final publishedListing = await _rpc(
      client,
      url,
      anonKey,
      host.token,
      'publish_listing',
      {'p_property_id': propertyId},
    );
    _expectOk(publishedListing, 'publish_listing');

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
    final publishedRequirement = await _rpc(
      client,
      url,
      anonKey,
      tenant.token,
      'publish_requirement',
      {'p_requirement_id': requirementId},
    );
    _expectOk(publishedRequirement, 'publish_requirement');

    await _rpc(client, url, anonKey, tenant.token, 'create_interest', {
      'p_target_type': 'property',
      'p_target_id': propertyId,
      'p_action': 'like',
    });
    final matched =
        await _rpc(client, url, anonKey, host.token, 'create_interest', {
          'p_target_type': 'listing_requirement',
          'p_target_id': requirementId,
          'p_action': 'like',
        });
    final match = matched['match'];
    if (match is! Map || match['ok'] != true || match['match_id'] is! String) {
      throw StateError('A mutual like did not open a match.');
    }
    final matchId = match['match_id'] as String;

    final opened = await _rpc(
      client,
      url,
      anonKey,
      tenant.token,
      'open_conversation',
      {'p_match_id': matchId},
    );
    _expectOk(opened, 'open_conversation');
    _expectNoContact(opened, 'open_conversation');
    final conversationId = opened['conversation_id'];
    if (conversationId is! String) {
      throw StateError('open_conversation did not return an id.');
    }

    final sent = await _rpc(
      client,
      url,
      anonKey,
      tenant.token,
      'send_message',
      {'p_conversation_id': conversationId, 'p_body': 'See you at 11'},
    );
    _expectOk(sent, 'send_message');
    _expectNoContact(sent, 'send_message');

    final refused = await _rpc(
      client,
      url,
      anonKey,
      tenant.token,
      'send_message',
      {'p_conversation_id': conversationId, 'p_body': 'call 9876543210'},
    );
    if (refused['error'] != 'contact') {
      throw StateError('A phone number was not refused.');
    }
    _expectNoContact(refused, 'refused message');

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
    _expectOk(visit, 'request_visit');
    _expectNoContact(visit, 'request_visit');
    if (visit['status'] != 'requested' || visit['visit_id'] is! String) {
      throw StateError('Visit was not requested.');
    }

    final accepted = await _rpc(
      client,
      url,
      anonKey,
      host.token,
      'respond_visit',
      {'p_visit_id': visit['visit_id'], 'p_status': 'accepted'},
    );
    _expectOk(accepted, 'respond_visit');
    _expectNoContact(accepted, 'respond_visit');
    if (accepted['status'] != 'accepted') {
      throw StateError('Visit was not accepted.');
    }

    final messages = jsonDecode(
      await _rest(
        client,
        url,
        anonKey,
        stranger.token,
        'GET',
        'messages?select=body',
        null,
      ),
    );
    if (messages is! List || messages.isNotEmpty) {
      throw StateError('A stranger could read chat.');
    }

    final cards = jsonDecode(
      await _rest(
        client,
        url,
        anonKey,
        tenant.token,
        'GET',
        'properties?id=eq.$propertyId&select=title,locality,city',
        null,
      ),
    );
    if (cards is! List || cards.length != 1 || cards.single is! Map) {
      throw StateError('Listing card was not readable.');
    }
    final card = (cards.single as Map).cast<String, dynamic>();
    for (final key in ['phone', 'email', 'address_line']) {
      if (card.containsKey(key)) {
        throw StateError('Listing card included $key');
      }
    }
    stdout.writeln('chat and visit check passed');
  } finally {
    client.close(force: true);
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
        'email': 'chat-$label-$stamp@example.test',
        'password': 'local-chat-check-1',
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

void _expectNoContact(Map<String, dynamic> body, String label) {
  for (final key in ['phone', 'email', 'address_line', 'landmark', 'aadhaar']) {
    if (body.containsKey(key)) {
      throw StateError('$label included $key.');
    }
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

String _uuid() {
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
