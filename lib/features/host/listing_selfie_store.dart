import 'dart:typed_data';

import 'package:homizi/features/listings/domain/photo_upload.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where an optional listing selfie was kept.
///
/// [keptLocally] is always true: the bytes stay on this device.
/// [storagePath] is set only when [listingPhotosBucket] already exists and
/// accepted the file. This never creates a bucket.
class ListingSelfieSave {
  const ListingSelfieSave({required this.keptLocally, this.storagePath});

  final bool keptLocally;
  final String? storagePath;
}

/// Reads bucket names and writes one object. Tests pass a fake.
abstract class ListingSelfieRemote {
  Future<List<String>> bucketIds();

  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });

  String? get userId;
}

/// JPEG, PNG, or WebP from the file header. Anything else is sent as JPEG
/// only when the bucket already allows that type; the caller still keeps
/// the original bytes locally.
String listingSelfieContentType(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46) {
    return 'image/webp';
  }
  return 'image/jpeg';
}

String listingSelfieObjectPath(String userId, String contentType) {
  final ext = switch (contentType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    _ => 'jpg',
  };
  return '$userId/listing-selfie.$ext';
}

/// Keeps the selfie on the device. Uploads a copy only when the private
/// listing-photos bucket is already on the project.
Future<ListingSelfieSave> saveListingSelfie({
  required Uint8List bytes,
  ListingSelfieRemote? remote,
}) async {
  if (remote == null || bytes.isEmpty) {
    return const ListingSelfieSave(keptLocally: true);
  }
  final userId = remote.userId;
  if (userId == null || userId.isEmpty) {
    return const ListingSelfieSave(keptLocally: true);
  }
  try {
    final ids = await remote.bucketIds();
    if (!ids.contains(listingPhotosBucket) ||
        bytes.length > maxListingPhotoBytes) {
      return const ListingSelfieSave(keptLocally: true);
    }
    final type = listingSelfieContentType(bytes);
    final path = listingSelfieObjectPath(userId, type);
    await remote.upload(path: path, bytes: bytes, contentType: type);
    return ListingSelfieSave(keptLocally: true, storagePath: path);
  } on Object {
    // Storage errors can echo a path. They are not shown or logged.
    return const ListingSelfieSave(keptLocally: true);
  }
}

class SupabaseListingSelfieRemote implements ListingSelfieRemote {
  SupabaseListingSelfieRemote(this._client);

  final SupabaseClient _client;

  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Future<List<String>> bucketIds() async {
    final buckets = await _client.storage.listBuckets();
    return [for (final bucket in buckets) bucket.id];
  }

  @override
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _client.storage
        .from(listingPhotosBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
  }
}

/// Null when this build is not connected, or when Supabase was not started.
/// A missing client keeps the selfie on the device.
ListingSelfieRemote? listingSelfieRemoteForCurrentSession({
  required bool connect,
}) {
  if (!connect) {
    return null;
  }
  try {
    return SupabaseListingSelfieRemote(Supabase.instance.client);
  } on Object {
    return null;
  }
}
