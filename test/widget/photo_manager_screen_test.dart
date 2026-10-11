import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';
import 'package:homizi/features/listings/photo_file_picker.dart';
import 'package:homizi/features/listings/photo_manager_screen.dart';

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
}
