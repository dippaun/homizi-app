import 'package:homizi/core/media/photo_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A reference [PersonPhoto] can paint.
///
/// Assets, data URLs, and https URLs pass through. A storage key saved in
/// `profiles.avatar_path` becomes the public avatars-bucket URL. Null means
/// there is no photo, so the portrait may fall back to initials.
String? displayAvatarRef(String? ref) {
  final value = ref?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  final known = photoRefForDisplay(value);
  if (known != null) {
    return avatarObjectUrl(known);
  }
  if (!Supabase.instance.isInitialized) {
    return null;
  }
  final key = value.split('?').first;
  if (key.isEmpty || key.contains('://') || key.startsWith('assets/')) {
    return null;
  }
  try {
    return Supabase.instance.client.storage.from('avatars').getPublicUrl(key);
  } on Object {
    return null;
  }
}
