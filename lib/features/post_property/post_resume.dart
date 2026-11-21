import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a room-sharer listing continues after sign-in or registration.
class PostResume extends Notifier<String?> {
  @override
  String? build() => null;

  void remember(String path) => state = path;

  String? take() {
    final path = state;
    state = null;
    return path;
  }
}

final postResumeProvider = NotifierProvider<PostResume, String?>(
  PostResume.new,
);
