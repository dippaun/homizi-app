import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Camera and library reads for the profile wizard.
///
/// The selfie bytes stay on [ProfileMedia]. They are not a public avatar
/// until the person chooses "Use My Selfie as Profile Photo".
abstract class ProfileImageSource {
  Future<Uint8List?> captureSelfie();

  Future<Uint8List?> pickProfilePhoto();
}

class DeviceProfileImageSource implements ProfileImageSource {
  @override
  Future<Uint8List?> captureSelfie() => _pick(ImageSource.camera);

  @override
  Future<Uint8List?> pickProfilePhoto() => _pick(ImageSource.gallery);

  Future<Uint8List?> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1200,
        imageQuality: 80,
      );
      if (file == null) {
        return null;
      }
      return file.readAsBytes();
    } on Object {
      return null;
    }
  }
}

final profileImageSourceProvider = Provider<ProfileImageSource>(
  (ref) => DeviceProfileImageSource(),
);

class ProfileMediaState {
  const ProfileMediaState({this.selfie, this.photo});

  final Uint8List? selfie;
  final Uint8List? photo;
}

class ProfileMedia extends Notifier<ProfileMediaState> {
  @override
  ProfileMediaState build() => const ProfileMediaState();

  void setSelfie(Uint8List bytes) {
    state = ProfileMediaState(selfie: bytes, photo: state.photo);
  }

  void setPhoto(Uint8List bytes) {
    state = ProfileMediaState(selfie: state.selfie, photo: bytes);
  }

  void useSelfieAsPhoto() {
    final selfie = state.selfie;
    if (selfie == null) {
      return;
    }
    state = ProfileMediaState(selfie: selfie, photo: selfie);
  }

  void clear() => state = const ProfileMediaState();
}

final profileMediaProvider = NotifierProvider<ProfileMedia, ProfileMediaState>(
  ProfileMedia.new,
);
