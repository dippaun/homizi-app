import 'dart:convert';
import 'dart:typed_data';

/// How a photo reference should be drawn.
enum PhotoKind { empty, asset, network, dataUrl }

PhotoKind photoKind(String? ref) {
  final value = ref?.trim() ?? '';
  if (value.isEmpty) {
    return PhotoKind.empty;
  }
  if (value.startsWith('data:image/')) {
    return PhotoKind.dataUrl;
  }
  if (value.startsWith('https://') || value.startsWith('http://')) {
    return PhotoKind.network;
  }
  if (value.startsWith('assets/')) {
    return PhotoKind.asset;
  }
  return PhotoKind.empty;
}

Uint8List? dataUrlBytes(String ref) {
  final comma = ref.indexOf(',');
  if (comma < 0 || comma + 1 >= ref.length) {
    return null;
  }
  try {
    return base64Decode(ref.substring(comma + 1));
  } on FormatException {
    return null;
  }
}

/// Public demo media served with the web build.
const demoMediaOrigin = 'https://homizi.netlify.app/demo_media';

String demoMediaUrl(String fileName) => '$demoMediaOrigin/$fileName';

const demoPhotoFiles = <String>[
  'living_01.webp',
  'living_02.webp',
  'living_03.webp',
  'living_04.webp',
  'living_05.webp',
  'bed_01.webp',
  'bed_02.webp',
  'bed_03.webp',
  'bed_04.webp',
  'kitchen_01.webp',
  'kitchen_02.webp',
  'kitchen_03.webp',
  'bath_01.webp',
  'bath_02.webp',
  'exterior_01.webp',
  'exterior_02.webp',
  'exterior_03.webp',
  'balcony_01.webp',
  'balcony_02.webp',
  'dining_01.webp',
  'workspace_01.webp',
];

const demoAvatarFiles = <String>[
  'avatar_01.webp',
  'avatar_02.webp',
  'avatar_03.webp',
  'avatar_04.webp',
  'avatar_05.webp',
  'avatar_06.webp',
];

/// Bundled copies for demo mode and Android. Same frames as [demoMediaUrl].
List<String> bundledPhotos(int start, int count) {
  final total = demoPhotoFiles.length;
  final n = count.clamp(3, 6);
  return [
    for (var i = 0; i < n; i++)
      'assets/photos/${demoPhotoFiles[(start + i) % total]}',
  ];
}

String bundledAvatar(int index) {
  return 'assets/avatars/${demoAvatarFiles[index % demoAvatarFiles.length]}';
}
