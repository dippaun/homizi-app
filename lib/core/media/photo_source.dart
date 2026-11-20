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

/// Card-sized URL for a Supabase public object. Signed URLs are left alone:
/// their token is bound to the object path, so a render rewrite would 403.
/// Other hosts (Netlify demo frames) stay as-is and are decoded down with
/// one cache dimension at the image widget.
///
/// Only `width` is sent, with `resize=contain`. A width plus a height, or
/// `resize=fill`, would squash the photo into that box.
String listingThumbnailUrl(String ref) {
  final trimmed = ref.trim();
  const marker = '/storage/v1/object/public/';
  final index = trimmed.indexOf(marker);
  if (index < 0 || trimmed.contains('token=')) {
    return trimmed;
  }
  final rewritten = trimmed.replaceFirst(
    marker,
    '/storage/v1/render/image/public/',
  );
  final join = rewritten.contains('?') ? '&' : '?';
  return '$rewritten${join}width=720&quality=70&resize=contain';
}

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

/// Stable bundled frame when a network photo cannot be drawn.
String fallbackHomePhoto(int seed) {
  const files = demoPhotoFiles;
  final index = seed.abs() % files.length;
  return 'assets/photos/${files[index]}';
}

/// Demo media is stored as `https://homizi.netlify.app/demo_media/<file>`.
/// That host does not send CORS headers, and Flutter web decodes network
/// images by fetching bytes, so those URLs paint blank. The same frames are
/// bundled, so a known file is drawn from assets instead.
String? photoRefForDisplay(String? ref) {
  final value = ref?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('assets/') || value.startsWith('data:image/')) {
    return value;
  }
  final file = _photoFileName(value);
  if (demoPhotoFiles.contains(file)) {
    return 'assets/photos/$file';
  }
  if (demoAvatarFiles.contains(file)) {
    return 'assets/avatars/$file';
  }
  if (photoKind(value) == PhotoKind.network) {
    return value;
  }
  return null;
}

/// Photo refs for a card. An empty or failed set becomes bundled home frames.
List<String> displayPhotoList(List<String> refs, {int seed = 0}) {
  final shown = <String>[];
  for (final ref in refs) {
    final next = photoRefForDisplay(ref);
    if (next != null && next.isNotEmpty) {
      shown.add(next);
    }
  }
  if (shown.isEmpty) {
    return bundledPhotos(seed, 3);
  }
  return shown;
}

String _photoFileName(String value) {
  final noQuery = value.split('?').first;
  final slash = noQuery.lastIndexOf('/');
  final name = slash < 0 ? noQuery : noQuery.substring(slash + 1);
  return name.toLowerCase();
}
