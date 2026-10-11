import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';

void main() {
  test('a photo file is stored under the owner and stays pending', () {
    final plan = planListingPhotoWrites(
      userId: 'user-1',
      propertyId: 'prop-1',
      newFileId: () => 'file-1',
      photos: [
        PhotoSlot(
          label: 'Living room',
          isPrimary: true,
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/jpeg',
        ),
      ],
    );

    expect(plan.uploads.single.path, 'user-1/prop-1/file-1.jpg');
    expect(plan.uploads.single.contentType, 'image/jpeg');
    expect(plan.uploads.single.path, isNot(contains('9876543210')));
    expect(plan.rows.single['storage_path'], 'user-1/prop-1/file-1.jpg');
    expect(plan.rows.single.keys, photoSlotColumns);
    expect(plan.photos.single.bytes, isNull);
    expect(plan.photos.single.moderationStatus, 'pending');
    expect(plan.storedFile, isTrue);
    for (final row in plan.rows) {
      expect(
        row.keys.toSet().intersection(forbiddenClientWriteColumns),
        isEmpty,
      );
      expect(row.containsKey('phone'), isFalse);
      expect(row.containsKey('email'), isFalse);
      expect(row.containsKey('address_line'), isFalse);
    }
  });

  test('an existing image path is replaced in place', () {
    final plan = planListingPhotoWrites(
      userId: 'user-1',
      propertyId: 'prop-1',
      newFileId: () => 'file-2',
      photos: [
        PhotoSlot(
          label: 'Bedroom',
          isPrimary: true,
          bytes: Uint8List.fromList([4, 5]),
          contentType: 'image/png',
          storagePath: 'user-1/prop-1/keep.png',
        ),
      ],
    );

    expect(plan.uploads.single.path, 'user-1/prop-1/keep.png');
    expect(plan.rows.single['storage_path'], 'user-1/prop-1/keep.png');
  });

  test('an empty slot does not upload a file', () {
    final plan = planListingPhotoWrites(
      userId: 'user-1',
      propertyId: 'prop-1',
      newFileId: () => 'file-3',
      photos: const [PhotoSlot(label: 'Kitchen', isPrimary: true)],
    );

    expect(plan.uploads, isEmpty);
    expect(plan.rows.single['storage_path'], 'user-1/prop-1/0.slot');
    expect(plan.storedFile, isFalse);
  });

  test('a slot path is not reused once a file is chosen', () {
    final plan = planListingPhotoWrites(
      userId: 'user-1',
      propertyId: 'prop-1',
      newFileId: () => 'file-4',
      photos: [
        PhotoSlot(
          label: 'Kitchen',
          isPrimary: true,
          bytes: Uint8List.fromList([9]),
          contentType: 'image/webp',
          storagePath: 'user-1/prop-1/0.slot',
        ),
      ],
    );

    expect(plan.uploads.single.path, 'user-1/prop-1/file-4.webp');
  });

  test('paths outside the owner folder are refused', () {
    expect(
      () => planListingPhotoWrites(
        userId: 'user-1',
        propertyId: 'prop-1',
        newFileId: () => 'file-5',
        photos: const [
          PhotoSlot(
            label: 'Exterior',
            isPrimary: true,
            storagePath: 'other-user/prop-1/file.jpg',
          ),
        ],
      ),
      throwsA(isA<PhotoUploadRejection>()),
    );
    expect(
      isOwnerScopedListingPhotoPath('user-1/../secret.jpg', 'user-1'),
      isFalse,
    );
    expect(
      listingPhotoObjectPath(
        userId: 'user-1',
        propertyId: 'prop-1',
        fileId: '9876543210',
        contentType: 'image/jpeg',
      ),
      'user-1/prop-1/9876543210.jpg',
    );
  });

  test('oversized and unsupported files are refused before upload', () {
    expect(
      listingPhotoRejection(Uint8List(maxListingPhotoBytes + 1), 'image/jpeg'),
      'Keep each photo under 5 MB.',
    );
    expect(
      listingPhotoRejection(Uint8List.fromList([1]), 'image/gif'),
      'Use a JPEG, PNG, or WebP photo.',
    );
    expect(contentTypeForPhotoName('lease.pdf', 'application/pdf'), isNull);
    expect(contentTypeForPhotoName('+919876543210.jpg', null), 'image/jpeg');
  });
}
