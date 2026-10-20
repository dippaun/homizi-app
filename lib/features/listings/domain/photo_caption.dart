/// Optional photo description. Empty means the gallery speaks the room type.
const maxListingCaptionLength = 80;

final _emailInCaption = RegExp(
  r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}',
);

/// True when [text] hides a phone number behind spaces, dots, or dashes.
bool captionHasPhone(String text) {
  final collapsed = text.replaceAll(RegExp(r'(?<=\d)[\s.\-]+(?=\d)'), '');
  return RegExp(r'\d{10,}').hasMatch(collapsed);
}

/// Null when [raw] may be stored. A blank caption is allowed.
String? listingCaptionRejection(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  if (text.length > maxListingCaptionLength) {
    return 'Keep the caption to 80 characters.';
  }
  if (_emailInCaption.hasMatch(text)) {
    return 'A caption cannot include an email.';
  }
  if (captionHasPhone(text)) {
    return 'A caption cannot include a phone number.';
  }
  return null;
}

/// Column value for `property_photos.caption`. Blank becomes null.
String? listingCaptionForStorage(String raw) {
  final text = raw.trim();
  if (text.isEmpty) {
    return null;
  }
  return text;
}

String roomLabelForPhotoType(String photoType) {
  switch (photoType) {
    case 'living':
      return 'Living room';
    case 'bedroom':
      return 'Bedroom';
    case 'kitchen':
      return 'Kitchen';
    case 'bathroom':
      return 'Bathroom';
    case 'exterior':
      return 'Exterior';
    default:
      return 'Other';
  }
}

/// Demo and bundled files encode the room in the file name.
String roomLabelForAsset(String asset) {
  final name = asset.toLowerCase();
  if (name.contains('living')) {
    return 'Living room';
  }
  if (name.contains('kitchen')) {
    return 'Kitchen';
  }
  if (name.contains('bath')) {
    return 'Bathroom';
  }
  if (name.contains('bed')) {
    return 'Bedroom';
  }
  if (name.contains('exterior')) {
    return 'Exterior';
  }
  return 'Other';
}

/// Gallery label. A safe caption wins. Otherwise the room, as in "Living room photo".
String photoSemanticsLabel({String? caption, required String roomLabel}) {
  final text = caption?.trim() ?? '';
  if (text.isNotEmpty && listingCaptionRejection(text) == null) {
    return text;
  }
  final room = roomLabel.trim();
  if (room.isEmpty) {
    return 'Photo';
  }
  return '$room photo';
}

List<String> galleryLabelsForAssets(List<String> assets) {
  return [
    for (final asset in assets)
      photoSemanticsLabel(roomLabel: roomLabelForAsset(asset)),
  ];
}

/// Non-rejected photos, in sort order. A rejected row is not a gallery frame.
List<String> galleryLabelsFromPhotoRows(List<Map<String, dynamic>> rows) {
  final ordered = [...rows]
    ..sort((a, b) {
      int orderOf(Object? value) => value is num ? value.toInt() : 0;
      return orderOf(a['sort_order']).compareTo(orderOf(b['sort_order']));
    });
  return [
    for (final row in ordered)
      if (row['moderation_status'] != 'rejected')
        photoSemanticsLabel(
          caption: row['caption'] is String ? row['caption'] as String : null,
          roomLabel: roomLabelForPhotoType(
            row['photo_type'] is String ? row['photo_type'] as String : '',
          ),
        ),
  ];
}

/// Prefer server labels when they line up with the frames already on screen.
List<String> alignGalleryLabels({
  required List<String> assets,
  required List<String> fromServer,
}) {
  if (assets.isEmpty) {
    return fromServer;
  }
  if (fromServer.length == assets.length) {
    return fromServer;
  }
  return [
    for (var index = 0; index < assets.length; index++)
      index < fromServer.length && fromServer[index].trim().isNotEmpty
          ? fromServer[index]
          : photoSemanticsLabel(roomLabel: roomLabelForAsset(assets[index])),
  ];
}
