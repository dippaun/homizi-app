import 'dart:typed_data';

import 'package:homizi/features/listings/domain/listing_draft.dart';

/// Private Supabase Storage bucket. Objects are not public.
const listingPhotosBucket = 'listing-photos';

/// Matches the bucket file size limit in the storage migration.
const maxListingPhotoBytes = 5 * 1024 * 1024;

const _extensions = <String, String>{
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

final _segment = RegExp(r'^[A-Za-z0-9_-]{1,80}$');

class PhotoUploadRejection implements Exception {
  const PhotoUploadRejection(this.message);

  final String message;

  @override
  String toString() => message;
}

class PickedListingPhoto {
  const PickedListingPhoto({required this.bytes, required this.contentType});

  final Uint8List bytes;

  /// Null when the file is not a JPEG, PNG, or WebP.
  final String? contentType;
}

String? listingPhotoExtension(String contentType) {
  final normalized = contentType.toLowerCase().split(';').first.trim();
  return _extensions[normalized];
}

String? contentTypeForPhotoName(String name, String? mimeType) {
  final mime = mimeType?.toLowerCase().split(';').first.trim();
  if (mime != null && listingPhotoExtension(mime) != null) {
    return mime;
  }
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  return null;
}

/// True when [path] is `{userId}/{propertyId}/{file}` with a known extension.
/// The original file name is never part of the path.
bool isOwnerScopedListingPhotoPath(String path, String userId) {
  if (userId.isEmpty || path.contains('..') || path.contains('\\')) {
    return false;
  }
  final parts = path.split('/');
  if (parts.length != 3 || parts[0] != userId) {
    return false;
  }
  if (!_segment.hasMatch(parts[1])) {
    return false;
  }
  final file = parts[2];
  final dot = file.lastIndexOf('.');
  if (dot <= 0 || dot == file.length - 1) {
    return false;
  }
  final stem = file.substring(0, dot);
  final extension = file.substring(dot + 1);
  if (!_segment.hasMatch(stem)) {
    return false;
  }
  return extension == 'jpg' ||
      extension == 'png' ||
      extension == 'webp' ||
      extension == 'slot';
}

bool isStoredImagePath(String path, String userId) {
  if (!isOwnerScopedListingPhotoPath(path, userId)) {
    return false;
  }
  return path.endsWith('.jpg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp');
}

bool photoReferencesStoredFile(PhotoSlot photo) {
  final path = photo.storagePath;
  if (path == null) {
    return false;
  }
  return path.endsWith('.jpg') ||
      path.endsWith('.png') ||
      path.endsWith('.webp');
}

void assertListingPhotoFile(Uint8List bytes, String contentType) {
  if (listingPhotoExtension(contentType) == null) {
    throw const PhotoUploadRejection('Use a JPEG, PNG, or WebP photo.');
  }
  if (bytes.isEmpty) {
    throw const PhotoUploadRejection('That photo file is empty.');
  }
  if (bytes.length > maxListingPhotoBytes) {
    throw const PhotoUploadRejection('Keep each photo under 5 MB.');
  }
}

String? listingPhotoRejection(Uint8List bytes, String contentType) {
  try {
    assertListingPhotoFile(bytes, contentType);
    return null;
  } on PhotoUploadRejection catch (error) {
    return error.message;
  }
}

String listingPhotoObjectPath({
  required String userId,
  required String propertyId,
  required String fileId,
  required String contentType,
}) {
  final extension = listingPhotoExtension(contentType);
  if (extension == null ||
      !_segment.hasMatch(userId) ||
      !_segment.hasMatch(propertyId) ||
      !_segment.hasMatch(fileId)) {
    throw const PhotoUploadRejection('Photo paths stay under your account.');
  }
  final path = '$userId/$propertyId/$fileId.$extension';
  if (!isStoredImagePath(path, userId)) {
    throw const PhotoUploadRejection('Photo paths stay under your account.');
  }
  return path;
}
