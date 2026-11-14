import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/auth/otp/indian_phone.dart';
import 'package:homizi/features/auth/otp/otp_messages.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/session/session_controller.dart';

class PostContact {
  const PostContact({
    this.fullName = '',
    this.mobile = '',
    this.email = '',
    this.mobileVerified = false,
    this.emailVerified = false,
  });

  final String fullName;
  final String mobile;
  final String email;
  final bool mobileVerified;
  final bool emailVerified;

  PostContact copyWith({
    String? fullName,
    String? mobile,
    String? email,
    bool? mobileVerified,
    bool? emailVerified,
  }) {
    return PostContact(
      fullName: fullName ?? this.fullName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      mobileVerified: mobileVerified ?? this.mobileVerified,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}

class PostContactController extends Notifier<PostContact> {
  @override
  PostContact build() => const PostContact();

  void replace(PostContact next) => state = next;

  void markMobile(String mobile) {
    state = state.copyWith(mobile: mobile, mobileVerified: true);
  }

  void markEmail(String email) {
    state = state.copyWith(email: email, emailVerified: true);
  }
}

final postContactProvider =
    NotifierProvider<PostContactController, PostContact>(
      PostContactController.new,
    );

enum PostOtpChannel { mobile, email }

class PostOtpTarget {
  const PostOtpTarget({required this.channel, required this.contact});

  final PostOtpChannel channel;
  final String contact;
}

class PostOtpTargetController extends Notifier<PostOtpTarget?> {
  @override
  PostOtpTarget? build() => null;

  void set(PostOtpTarget? next) => state = next;
}

final postOtpTargetProvider =
    NotifierProvider<PostOtpTargetController, PostOtpTarget?>(
      PostOtpTargetController.new,
    );

/// Sends a code through the existing auth OTP path. When that path is the
/// on-device demo (no SMS provider), a valid contact still counts as sent
/// and [verifyPostCode] accepts [AppConfig.devOtp].
Future<String?> sendPostCode(
  WidgetRef ref, {
  required bool mobile,
  required String contact,
}) async {
  if (mobile) {
    if (indianMobileE164(contact) == null) {
      return indianMobileInvalidMessage;
    }
  } else {
    final invalid = validateEmailAddress(contact);
    if (invalid != null) {
      return invalid;
    }
  }
  final config = ref.read(appConfigProvider);
  final session = ref.read(sessionProvider.notifier);
  final error = mobile
      ? await session.requestPhoneCode(
          contact,
          link: ref.read(sessionProvider).userId != null,
        )
      : await session.requestEmailCode(contact);
  if (error == null) {
    return null;
  }
  if (config.allowsDevOtp) {
    return null;
  }
  return error;
}

/// Checks the code with the existing session verifier, then the demo code.
Future<String?> verifyPostCode(
  WidgetRef ref, {
  required bool mobile,
  required String contact,
  required String code,
}) async {
  final config = ref.read(appConfigProvider);
  final session = ref.read(sessionProvider.notifier);
  if (mobile) {
    final error = await session.verifyPhoneCode(
      raw: contact,
      code: code,
      link: ref.read(sessionProvider).userId != null,
    );
    if (error == null) {
      return null;
    }
    if (config.allowsDevOtp && code.trim() == AppConfig.devOtp) {
      return null;
    }
    return error;
  }
  if (!config.usesHostedEmailOtp || ref.read(forceDemoModeProvider)) {
    if (config.allowsDevOtp && code.trim() == AppConfig.devOtp) {
      return null;
    }
    return 'Enter the 6-digit code from the email.';
  }
  if (config.environment == AppEnvironment.prod &&
      code.trim() == AppConfig.devOtp) {
    return 'That code is not accepted.';
  }
  return session.signIn(contact: contact, code: code.trim());
}
