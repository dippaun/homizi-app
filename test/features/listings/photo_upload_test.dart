import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_payload.dart';
import 'package:homizi/features/listings/domain/photo_caption.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';

void main() {
  test('a failed upload can be retried without dropping the file', () {
    final original = PhotoSlot(
      label: 'Living room',
      isPrimary: true,
      bytes: Uint8List.fromList(const [1, 2, 3]),
      contentType: 'image/jpeg',
    );
    final failed = PhotoTransfer.fail(
      PhotoTransfer.advance(PhotoTransfer.begin(original), 0.4),
      'The photo could not be saved.',
    );
    expect(failed.transferError, 'The photo could not be saved.');
    expect(failed.bytes, original.bytes);
    expect(failed.transferAttempt, 0);

    final retried = PhotoTransfer.retry(failed);
    expect(retried.transferError, isNull);
    expect(retried.transferProgress, 0);
    expect(retried.transferAttempt, 1);
    expect(retried.bytes, original.bytes);

    final done = PhotoTransfer.finish(retried);
    expect(done.transferProgress, 1);
    expect(done.transferError, isNull);
  });

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
    expect(plan.rows.single['caption'], isNull);
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

  test('storage errors name a missing policy or bucket', () {
    expect(
      storageFailureMessage(
        'new row violates row-level security policy for table "objects"',
      ),
      'Photo upload was refused. The listing-photos policies are not installed on this project yet.',
    );
    expect(
      storageFailureMessage('Bucket not found'),
      'The listing-photos bucket is missing on this project.',
    );
    expect(
      storageFailureMessage('mime type image/gif is not supported'),
      'Use a JPEG, PNG, or WebP photo.',
    );
    expect(
      storageFailureMessage('note for ada@example.test'),
      'The photo could not be saved.',
    );
  });

  test('a caption is stored and a phone or email is refused', () {
    final plan = planListingPhotoWrites(
      userId: 'user-1',
      propertyId: 'prop-1',
      newFileId: () => 'file-6',
      photos: [
        PhotoSlot(
          label: 'Living room',
          isPrimary: true,
          bytes: Uint8List.fromList([1, 2, 3]),
          contentType: 'image/jpeg',
          caption: '  Morning light  ',
        ),
      ],
    );

    expect(plan.rows.single['caption'], 'Morning light');
    expect(plan.rows.single.containsKey('moderation_status'), isFalse);
    expect(plan.photos.single.moderationStatus, 'pending');
    expect(
      photoSemanticsLabel(caption: 'Morning light', roomLabel: 'Living room'),
      'Morning light',
    );
    expect(
      photoSemanticsLabel(caption: '   ', roomLabel: 'Living room'),
      'Living room photo',
    );
    expect(
      photoSemanticsLabel(caption: '9876543210', roomLabel: 'Living room'),
      'Living room photo',
    );

    expect(
      () => planListingPhotoWrites(
        userId: 'user-1',
        propertyId: 'prop-1',
        newFileId: () => 'file-7',
        photos: const [
          PhotoSlot(
            label: 'Bedroom',
            isPrimary: true,
            caption: 'Call 98765 43210 today',
          ),
        ],
      ),
      throwsA(
        isA<PhotoUploadRejection>().having(
          (error) => error.message,
          'message',
          'A caption cannot include a phone number.',
        ),
      ),
    );
    expect(
      listingCaptionRejection('ada@example.test'),
      'A caption cannot include an email.',
    );
    expect(
      listingCaptionRejection('x' * 81),
      'Keep the caption to 80 characters.',
    );
    expect(listingCaptionRejection(''), isNull);
  });

  test('video is refused and the photo types stay jpeg png and webp', () {
    expect(contentTypeForPhotoName('tour.mp4', 'video/mp4'), isNull);
    expect(
      listingPhotoRejection(Uint8List.fromList([1, 2, 3, 4]), 'video/mp4'),
      'Use a JPEG, PNG, or WebP photo.',
    );
    expect(listingPhotoExtension('video/mp4'), isNull);
    expect(
      galleryLabelsForAssets(const [
        'assets/photos/living_01.webp',
        'assets/photos/bed_01.webp',
      ]),
      ['Living room photo', 'Bedroom photo'],
    );
    expect(
      galleryLabelsFromPhotoRows(const [
        {
          'sort_order': 1,
          'photo_type': 'bedroom',
          'caption': 'Quiet room',
          'moderation_status': 'approved',
        },
        {
          'sort_order': 0,
          'photo_type': 'living',
          'caption': null,
          'moderation_status': 'pending',
        },
        {
          'sort_order': 2,
          'photo_type': 'kitchen',
          'caption': 'Hidden',
          'moderation_status': 'rejected',
        },
      ]),
      ['Living room photo', 'Quiet room'],
    );
  });
}
