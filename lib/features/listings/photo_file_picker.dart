import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/listings/domain/photo_upload.dart';
import 'package:image_picker/image_picker.dart';

/// Chooses one image from the device. Tests replace this provider.
abstract interface class PhotoFilePicker {
  Future<PickedListingPhoto?> pick();
}

/// The gallery plugin is missing or refused the request. Nothing was uploaded.
class PhotoPickUnavailable implements Exception {
  const PhotoPickUnavailable();

  static const message =
      'This browser could not open the photo library. Nothing was uploaded.';

  @override
  String toString() => message;
}

class GalleryPhotoFilePicker implements PhotoFilePicker {
  @override
  Future<PickedListingPhoto?> pick() async {
    try {
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
    } catch (_) {
      throw const PhotoPickUnavailable();
    }
  }
}

final photoFilePickerProvider = Provider<PhotoFilePicker>(
  (ref) => GalleryPhotoFilePicker(),
);
