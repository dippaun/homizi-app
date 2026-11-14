import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/host/listing_selfie_store.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';

void main() {
  test('a selfie stays on the device when no bucket is present', () async {
    final remote = _Remote(buckets: const ['avatars']);
    final saved = await saveListingSelfie(
      bytes: Uint8List.fromList([1, 2, 3]),
      remote: remote,
    );
    expect(saved.keptLocally, isTrue);
    expect(saved.storagePath, isNull);
    expect(remote.uploaded, isNull);
  });

  test(
    'a selfie is copied only when the listing photo bucket exists',
    () async {
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        1,
      ]);
      final remote = _Remote(buckets: const [listingPhotosBucket]);
      final saved = await saveListingSelfie(bytes: png, remote: remote);
      expect(saved.keptLocally, isTrue);
      expect(saved.storagePath, 'user-1/listing-selfie.png');
      expect(remote.uploaded, png);
      expect(remote.uploadedType, 'image/png');
    },
  );

  test('a missing session or a failed bucket read stays local', () async {
    final bytes = Uint8List.fromList([9]);
    final signedOut = await saveListingSelfie(
      bytes: bytes,
      remote: _Remote(buckets: const [listingPhotosBucket], userId: null),
    );
    expect(signedOut.storagePath, isNull);

    final offline = await saveListingSelfie(bytes: bytes);
    expect(offline.keptLocally, isTrue);
    expect(offline.storagePath, isNull);

    final failed = await saveListingSelfie(
      bytes: bytes,
      remote: _Remote(buckets: const [listingPhotosBucket], throwsOnList: true),
    );
    expect(failed.storagePath, isNull);
  });

  test('jpeg and webp headers pick the matching object name', () {
    expect(
      listingSelfieContentType(Uint8List.fromList([0xFF, 0xD8, 0xFF])),
      'image/jpeg',
    );
    expect(
      listingSelfieObjectPath('abc', 'image/webp'),
      'abc/listing-selfie.webp',
    );
  });
}

class _Remote implements ListingSelfieRemote {
  _Remote({
    required this.buckets,
    this.userId = 'user-1',
    this.throwsOnList = false,
  });

  final List<String> buckets;
  @override
  final String? userId;
  final bool throwsOnList;
  Uint8List? uploaded;
  String? uploadedType;

  @override
  Future<List<String>> bucketIds() async {
    if (throwsOnList) {
      throw StateError('bucket list failed');
    }
    return buckets;
  }

  @override
  Future<void> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    uploaded = bytes;
    uploadedType = contentType;
  }
}
