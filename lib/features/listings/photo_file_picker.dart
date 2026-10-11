import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';
import 'package:image_picker/image_picker.dart';

/// Chooses one image from the device. Tests replace this provider.
abstract interface class PhotoFilePicker {
  Future<PickedListingPhoto?> pick();
}

class GalleryPhotoFilePicker implements PhotoFilePicker {
  @override
  Future<PickedListingPhoto?> pick() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (image == null) {
      return null;
    }
    final bytes = await image.readAsBytes();
    return PickedListingPhoto(
      bytes: bytes,
      contentType: contentTypeForPhotoName(image.name, image.mimeType),
    );
  }
}

final photoFilePickerProvider = Provider<PhotoFilePicker>(
  (ref) => GalleryPhotoFilePicker(),
);
