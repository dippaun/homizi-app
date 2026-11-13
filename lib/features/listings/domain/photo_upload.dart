import 'dart:typed_data';

import 'package:homizi/features/listings/domain/listing_draft.dart';

/// Upload progress for one listing photo. Retry clears the error and
/// increments the attempt. Bytes stay on the slot until a private path exists.
abstract final class PhotoTransfer {
  static PhotoSlot begin(PhotoSlot photo) {
    return photo.copyWith(transferProgress: 0, clearTransferError: true);
  }

  static PhotoSlot advance(PhotoSlot photo, double progress) {
    final next = progress.clamp(0.0, 1.0).toDouble();
    return photo.copyWith(transferProgress: next, clearTransferError: true);
  }

  static PhotoSlot fail(PhotoSlot photo, String message) {
    return photo.copyWith(transferError: message);
  }

  static PhotoSlot retry(PhotoSlot photo) {
    return photo.copyWith(
      transferProgress: 0,
      clearTransferError: true,
      transferAttempt: photo.transferAttempt + 1,
    );
  }

  static PhotoSlot finish(PhotoSlot photo) {
    return photo.copyWith(transferProgress: 1, clearTransferError: true);
  }
}

/// Private Supabase Storage bucket. Objects are not public.
const listingPhotosBucket = 'listing-photos';

/// Matches the bucket file size limit in the storage migration.
const maxListingPhotoBytes = 5 * 1024 * 1024;

/// JPEG, PNG, and WebP only. MP4 is refused: the private bucket stays at
/// 5 MB, and this app has no video player, so a 20 MB video cannot be an
/// extra in the same bucket without raising that limit or adding a package.
const _extensions = <String, String>{
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

final _segment = RegExp(r'^[A-Za-z0-9_-]{1,80}$');

/// Turns a Storage API error into a sentence for the listing screen.
/// The object path and any mailbox stay out of the text.
String storageFailureMessage(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('row-level security') ||
      lower.contains('row level security') ||
      lower.contains('42501') ||
      lower.contains('unauthorized') ||
      lower.contains('violates row-level')) {
    return 'Photo upload was refused. The listing-photos policies are not installed on this project yet.';
  }
  if (lower.contains('bucket not found') ||
      lower.contains('bucket_not_found')) {
    return 'The listing-photos bucket is missing on this project.';
  }
  if (lower.contains('payload too large') ||
      lower.contains('entity too large') ||
      lower.contains('file size') ||
      lower.contains('maximum allowed')) {
    return 'Keep each photo under 5 MB.';
  }
  if (lower.contains('mime') || lower.contains('content type')) {
    return 'Use a JPEG, PNG, or WebP photo.';
  }
  final trimmed = message.trim();
  if (trimmed.isEmpty ||
      trimmed.length > 180 ||
      trimmed.contains('@') ||
      trimmed.contains('+91')) {
    return 'The photo could not be saved.';
  }
  return trimmed;
}

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
  final size = imagePixelSize(bytes);
  if (size != null && !photoMeetsMinResolution(size.$1, size.$2)) {
    throw const PhotoUploadRejection('Use a photo at least 720 by 480 pixels.');
  }
}

/// 720 on the long side and 480 on the short side. Portrait photos pass.
bool photoMeetsMinResolution(int width, int height) {
  if (width < 1 || height < 1) {
    return false;
  }
  final longSide = width > height ? width : height;
  final shortSide = width > height ? height : width;
  return longSide >= 720 && shortSide >= 480;
}

/// Width and height from a JPEG, PNG, or WebP header. Null when the bytes
/// are not a readable image. Callers must not guess a size.
(int, int)? imagePixelSize(Uint8List bytes) {
  final png = _pngSize(bytes);
  if (png != null) {
    return png;
  }
  final webp = _webpSize(bytes);
  if (webp != null) {
    return webp;
  }
  return _jpegSize(bytes);
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

(int, int)? _pngSize(Uint8List bytes) {
  if (bytes.length < 24) {
    return null;
  }
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < sig.length; i++) {
    if (bytes[i] != sig[i]) {
      return null;
    }
  }
  final width = _u32(bytes, 16);
  final height = _u32(bytes, 20);
  if (width == null || height == null || width < 1 || height < 1) {
    return null;
  }
  return (width, height);
}

(int, int)? _jpegSize(Uint8List bytes) {
  if (bytes.length < 4 || bytes[0] != 0xFF || bytes[1] != 0xD8) {
    return null;
  }
  var offset = 2;
  while (offset + 8 < bytes.length) {
    if (bytes[offset] != 0xFF) {
      offset += 1;
      continue;
    }
    final marker = bytes[offset + 1];
    if (marker == 0xD8 || marker == 0xD9 || marker == 0x01) {
      offset += 2;
      continue;
    }
    if (offset + 3 >= bytes.length) {
      return null;
    }
    final length = (bytes[offset + 2] << 8) | bytes[offset + 3];
    if (length < 2) {
      return null;
    }
    final isStart =
        marker == 0xC0 || marker == 0xC1 || marker == 0xC2 || marker == 0xC3;
    if (isStart) {
      if (offset + 8 >= bytes.length) {
        return null;
      }
      final height = (bytes[offset + 5] << 8) | bytes[offset + 6];
      final width = (bytes[offset + 7] << 8) | bytes[offset + 8];
      if (width < 1 || height < 1) {
        return null;
      }
      return (width, height);
    }
    offset += 2 + length;
  }
  return null;
}

(int, int)? _webpSize(Uint8List bytes) {
  if (bytes.length < 30) {
    return null;
  }
  if (!_ascii(bytes, 0, 'RIFF') || !_ascii(bytes, 8, 'WEBP')) {
    return null;
  }
  if (_ascii(bytes, 12, 'VP8X') && bytes.length >= 30) {
    final width = 1 + bytes[24] + (bytes[25] << 8) + (bytes[26] << 16);
    final height = 1 + bytes[27] + (bytes[28] << 8) + (bytes[29] << 16);
    return (width, height);
  }
  if (_ascii(bytes, 12, 'VP8 ') && bytes.length >= 30) {
    final width = bytes[26] | ((bytes[27] & 0x3F) << 8);
    final height = bytes[28] | ((bytes[29] & 0x3F) << 8);
    if (width < 1 || height < 1) {
      return null;
    }
    return (width, height);
  }
  if (_ascii(bytes, 12, 'VP8L') && bytes.length >= 25) {
    final bits =
        bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
    final width = (bits & 0x3FFF) + 1;
    final height = ((bits >> 14) & 0x3FFF) + 1;
    return (width, height);
  }
  return null;
}

int? _u32(Uint8List bytes, int offset) {
  if (offset + 3 >= bytes.length) {
    return null;
  }
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

bool _ascii(Uint8List bytes, int offset, String text) {
  if (offset + text.length > bytes.length) {
    return false;
  }
  for (var i = 0; i < text.length; i++) {
    if (bytes[offset + i] != text.codeUnitAt(i)) {
      return false;
    }
  }
  return true;
}
