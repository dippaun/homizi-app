import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Latest hCaptcha token. Empty means the check is off or not finished.
class CaptchaToken extends Notifier<String> {
  @override
  String build() => '';

  void setToken(String? value) {
    state = value?.trim() ?? '';
  }
}

final captchaTokenProvider = NotifierProvider<CaptchaToken, String>(
  CaptchaToken.new,
);
