import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/listings/photo_file_picker.dart';
import 'package:homizi/features/listings/photo_manager_screen.dart';

class _ThrowingPicker implements PhotoFilePicker {
  @override
  Future<PickedListingPhoto?> pick() async {
    throw const PhotoPickUnavailable();
  }
}

class _ScriptedPicker implements PhotoFilePicker {
  _ScriptedPicker(this.photos);

  final List<PickedListingPhoto?> photos;
  var index = 0;

  @override
  Future<PickedListingPhoto?> pick() async {
    final photo = photos[index];
    index += 1;
    return photo;
  }
}

void main() {
  testWidgets('adding a photo keeps it on device and pending in demo mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final picker = _ScriptedPicker([
      PickedListingPhoto(
        bytes: Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]),
        contentType: 'image/jpeg',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [photoFilePickerProvider.overrideWith((ref) => picker)],
        child: const MaterialApp(home: PhotoManagerScreen()),
      ),
    );

    expect(find.textContaining('street address'), findsNothing);
    expect(find.textContaining('phone'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('Demo mode'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-listing-photo')));
    await tester.pumpAndSettle();

    expect(find.textContaining('On this device'), findsOneWidget);
    expect(find.textContaining('Pending review'), findsOneWidget);
    expect(find.textContaining('9876543210'), findsNothing);
    expect(find.byKey(const Key('listing-photo-preview-0')), findsOneWidget);
  });

  testWidgets('a file that is not an image is refused', (tester) async {
    final picker = _ScriptedPicker([
      PickedListingPhoto(
        bytes: Uint8List.fromList(const [1, 2, 3]),
        contentType: null,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [photoFilePickerProvider.overrideWith((ref) => picker)],
        child: const MaterialApp(home: PhotoManagerScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('add-listing-photo')));
    await tester.pumpAndSettle();

    expect(find.text('Use a JPEG, PNG, or WebP photo.'), findsOneWidget);
    expect(find.text('No photos yet.'), findsOneWidget);
  });

  testWidgets('a photo library failure uploads nothing', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoFilePickerProvider.overrideWith((ref) => _ThrowingPicker()),
        ],
        child: const MaterialApp(home: PhotoManagerScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('add-listing-photo')));
    await tester.pumpAndSettle();

    expect(find.text(PhotoPickUnavailable.message), findsOneWidget);
    expect(find.text('No photos yet.'), findsOneWidget);
  });

  testWidgets('a caption is kept and a phone number is refused', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final picker = _ScriptedPicker([
      PickedListingPhoto(
        bytes: Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]),
        contentType: 'image/jpeg',
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [photoFilePickerProvider.overrideWith((ref) => picker)],
        child: const MaterialApp(home: PhotoManagerScreen()),
      ),
    );

    await tester.tap(find.byKey(const Key('add-listing-photo')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('listing-photo-caption-0')),
      'Morning light in Koramangala',
    );
    await tester.pump();

    final element = tester.element(find.byType(PhotoManagerScreen));
    expect(
      ProviderScope.containerOf(
        element,
      ).read(listingDraftProvider).photos.single.caption,
      'Morning light in Koramangala',
    );

    await tester.enterText(
      find.byKey(const Key('listing-photo-caption-0')),
      'Call 9876543210',
    );
    await tester.pump();

    expect(
      find.text('A caption cannot include a phone number.'),
      findsOneWidget,
    );
    expect(find.textContaining('Pending review'), findsOneWidget);
  });

  testWidgets('approved and rejected are printed as words', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [listingDraftProvider.overrideWith(_ModeratedDraft.new)],
        child: const MaterialApp(home: PhotoManagerScreen()),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Approved'), findsOneWidget);
    expect(find.textContaining('Rejected'), findsOneWidget);
    expect(find.textContaining('Pending review'), findsNothing);
  });
}

class _ModeratedDraft extends ListingDraftController {
  @override
  ListingDraft build() {
    return const ListingDraft(
      photos: [
        PhotoSlot(
          label: 'Living room',
          isPrimary: true,
          moderationStatus: 'approved',
        ),
        PhotoSlot(
          label: 'Bedroom',
          isPrimary: false,
          moderationStatus: 'rejected',
        ),
      ],
    );
  }
}
