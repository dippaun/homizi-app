// Checks the local listing-photos bucket with the public anon key.
// Usage:
//   SUPABASE_URL=... SUPABASE_ANON_KEY=... dart run tool/listing_photo_upload_check.dart
// The key is the local public client key. This script does not use the service role.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const maxListingPhotoBytes = 5 * 1024 * 1024;

Future<void> main() async {
  final url = Platform.environment['SUPABASE_URL']?.trim() ?? '';
  final anonKey = Platform.environment['SUPABASE_ANON_KEY']?.trim() ?? '';
  if (url.isEmpty || anonKey.isEmpty) {
    stderr.writeln(
      'SUPABASE_URL and SUPABASE_ANON_KEY are required. '
      'Demo mode does not upload.',
    );
    exitCode = 1;
    return;
  }

  final client = HttpClient();
  try {
    final owner = await _session(client, url, anonKey, 'owner');
    final stranger = await _session(client, url, anonKey, 'stranger');
    final propertyId = _uuid();
    final cover = '${owner.userId}/$propertyId/${_uuid()}.jpg';
    final hidden = '${owner.userId}/$propertyId/${_uuid()}.jpg';
    final jpeg = base64Decode(
      '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAP//////////////////////////////////////////////2wBDAf//////////////////////////////////////////////wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAb/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIQAxAAAAGf/9k=',
    );

    await _expect(
      'owner uploads into their folder',
      await _send(
        client,
        'POST',
        '$url/storage/v1/object/listing-photos/$cover',
        anonKey,
        token: owner.token,
        contentType: 'image/jpeg',
        body: jpeg,
        headers: {'x-upsert': 'true'},
      ),
      {200, 201},
    );
    await _expect(
      'owner uploads a second file that stays unpublished',
      await _send(
        client,
        'POST',
        '$url/storage/v1/object/listing-photos/$hidden',
        anonKey,
        token: owner.token,
        contentType: 'image/jpeg',
        body: jpeg,
        headers: {'x-upsert': 'true'},
      ),
      {200, 201},
    );
    await _expect(
      'a non-image is refused',
      await _send(
        client,
        'POST',
        '$url/storage/v1/object/listing-photos/${owner.userId}/$propertyId/note.txt',
        anonKey,
        token: owner.token,
        contentType: 'text/plain',
        body: utf8.encode('not a photo'),
      ),
      {400, 415, 422},
    );
    await _expect(
      'a file over 5 MB is refused',
      await _send(
        client,
        'POST',
        '$url/storage/v1/object/listing-photos/${owner.userId}/$propertyId/big.jpg',
        anonKey,
        token: owner.token,
        contentType: 'image/jpeg',
        body: Uint8List(maxListingPhotoBytes + 1),
      ),
      {400, 413, 422},
    );
    await _expect(
      'another account cannot upload into the owner folder',
      await _send(
        client,
        'POST',
        '$url/storage/v1/object/listing-photos/$cover',
        anonKey,
        token: stranger.token,
        contentType: 'image/jpeg',
        body: jpeg,
        headers: {'x-upsert': 'true'},
      ),
      {400, 403},
    );

    await _rest(client, url, anonKey, owner.token, 'POST', 'properties', {
      'id': propertyId,
      'host_user_id': owner.userId,
      'title': 'Photo home',
      'locality': 'Baner',
      'city': 'Pune',
      'address_visibility': 'locality_only',
      'property_type': 'apartment',
      'furnishing': 'semi_furnished',
      'rent_inr': 18000,
      'deposit_inr': 0,
      'occupancy_max': 1,
    });
    await _rest(client, url, anonKey, owner.token, 'POST', 'property_photos', [
      {
        'property_id': propertyId,
        'storage_path': cover,
        'sort_order': 0,
        'photo_type': 'living',
      },
      {
        'property_id': propertyId,
        'storage_path': '${owner.userId}/$propertyId/1.slot',
        'sort_order': 1,
        'photo_type': 'bedroom',
      },
      {
        'property_id': propertyId,
        'storage_path': '${owner.userId}/$propertyId/2.slot',
        'sort_order': 2,
        'photo_type': 'kitchen',
      },
    ]);

    final photos = jsonDecode(
      await _rest(
        client,
        url,
        anonKey,
        owner.token,
        'GET',
        'property_photos?property_id=eq.$propertyId&select=moderation_status,storage_path',
        null,
      ),
    );
    if (photos is! List) {
      throw StateError('Photo rows were not a list.');
    }
    final coverRow = photos.cast<Map<String, dynamic>>().firstWhere(
      (row) => row['storage_path'] == cover,
    );
    if (coverRow['moderation_status'] != 'pending') {
      throw StateError('Expected pending moderation.');
    }
    for (final key in ['phone', 'email', 'address_line']) {
      if (coverRow.containsKey(key)) {
        throw StateError('Photo row included $key');
      }
    }

    final moderation = await _send(
      client,
      'PATCH',
      '$url/rest/v1/property_photos?property_id=eq.$propertyId',
      anonKey,
      token: owner.token,
      contentType: 'application/json',
      body: utf8.encode(jsonEncode({'moderation_status': 'approved'})),
      headers: {'Prefer': 'return=minimal'},
    );
    if (moderation.statusCode < 400) {
      throw StateError('Moderation write should fail.');
    }

    await _expect(
      'the owner can download a draft photo',
      await _send(
        client,
        'GET',
        '$url/storage/v1/object/listing-photos/$cover',
        anonKey,
        token: owner.token,
      ),
      {200},
    );
    await _expect(
      'another account cannot download an unpublished photo',
      await _send(
        client,
        'GET',
        '$url/storage/v1/object/listing-photos/$hidden',
        anonKey,
        token: stranger.token,
      ),
      {400, 403, 404},
    );

    final published = await _send(
      client,
      'POST',
      '$url/rest/v1/rpc/publish_listing',
      anonKey,
      token: owner.token,
      contentType: 'application/json',
      body: utf8.encode(jsonEncode({'p_property_id': propertyId})),
    );
    final publishedBody = jsonDecode(published.body);
    if (published.statusCode >= 400 ||
        publishedBody is! Map ||
        publishedBody['ok'] != true) {
      throw StateError('publish_listing failed.');
    }

    await _expect(
      'a published photo can be read by another signed-in user',
      await _send(
        client,
        'GET',
        '$url/storage/v1/object/listing-photos/$cover',
        anonKey,
        token: stranger.token,
      ),
      {200},
    );
    await _expect(
      'an unlinked photo stays hidden after publish',
      await _send(
        client,
        'GET',
        '$url/storage/v1/object/listing-photos/$hidden',
        anonKey,
        token: stranger.token,
      ),
      {400, 403, 404},
    );

    final cards = jsonDecode(
      await _rest(
        client,
        url,
        anonKey,
        stranger.token,
        'GET',
        'properties?id=eq.$propertyId&select=title,locality,city,rent_inr',
        null,
      ),
    );
    if (cards is! List || cards.length != 1 || cards.single is! Map) {
      throw StateError('Listing card was not readable.');
    }
    final card = (cards.single as Map).cast<String, dynamic>();
    for (final key in [
      'phone',
      'email',
      'address_line',
      'landmark',
      'latitude',
      'longitude',
    ]) {
      if (card.containsKey(key)) {
        throw StateError('Listing card included $key');
      }
    }
    if (card['locality'] != 'Baner' || card['city'] != 'Pune') {
      throw StateError('Listing card lost its locality.');
    }
    stdout.writeln('listing photo upload check passed');
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
  final email = 'photo-$label-$stamp@example.test';
  final response = await _send(
    client,
    'POST',
    '$url/auth/v1/signup',
    anonKey,
    contentType: 'application/json',
    body: utf8.encode(
      jsonEncode({'email': email, 'password': 'local-photo-check-1'}),
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

Future<void> _expect(String label, _Reply response, Set<int> allowed) async {
  if (!allowed.contains(response.statusCode)) {
    throw StateError('$label failed with HTTP ${response.statusCode}.');
  }
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
  final text = await response.transform(utf8.decoder).join();
  return _Reply(response.statusCode, text);
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
