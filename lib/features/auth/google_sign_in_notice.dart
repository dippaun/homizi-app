import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A Google sign-in sentence to show on the existing login screen.
class GoogleSignInNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String? message) => state = message;
}

final googleSignInNoticeProvider =
    NotifierProvider<GoogleSignInNotice, String?>(GoogleSignInNotice.new);
