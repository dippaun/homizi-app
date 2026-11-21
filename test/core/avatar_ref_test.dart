import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/media/photo_source.dart';

void main() {
  test('avatar object urls are not sent through the render endpoint', () {
    const render =
        'https://example.supabase.co/storage/v1/render/image/public/avatars/user/avatar.png?width=720';
    expect(
      avatarObjectUrl(render),
      'https://example.supabase.co/storage/v1/object/public/avatars/user/avatar.png?width=720',
    );
    const object =
        'https://example.supabase.co/storage/v1/object/public/avatars/user/avatar.png';
    expect(avatarObjectUrl(object), object);
  });
}
