import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/supabase_account_gateway.dart';
import 'package:homizi/features/auth/otp/captcha_token.dart';
import 'package:homizi/features/profile_create/profile_email_otp.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final profileEmailVerifierProvider = Provider<ProfileEmailVerifier>((ref) {
  final config = ref.watch(appConfigProvider);
  if (!config.usesHostedEmailOtp) {
    return const LocalProfileEmailVerifier();
  }
  final gateway = SupabaseAccountGateway(
    Supabase.instance.client,
    allowDevPassword: false,
    captchaToken: ref.watch(captchaTokenProvider),
    logAuthCodes: config.environment != AppEnvironment.prod,
  );
  return ProfileEmailFlow(
    production: config.environment == AppEnvironment.prod,
    auth: SupabaseProfileEmailAuth(gateway),
  );
});

class SupabaseProfileEmailAuth implements ProfileEmailAuth {
  SupabaseProfileEmailAuth(this._gateway);

  final SupabaseAccountGateway _gateway;

  @override
  AuthEmailUser? get currentUser => _from(_gateway.authUser);

  @override
  Future<void> sendSignInCode({
    required String email,
    required bool shouldCreateUser,
  }) {
    return _gateway.requestProfileSignInCode(
      email: email,
      shouldCreateUser: shouldCreateUser,
    );
  }

  @override
  Future<void> sendEmailChange(String email) {
    return _gateway.requestProfileEmailChange(email: email);
  }

  @override
  Future<bool> verifyCode({
    required String email,
    required String code,
    required bool emailChange,
  }) {
    return _gateway.verifyProfileEmailCode(
      email: email,
      code: code,
      emailChange: emailChange,
    );
  }

  @override
  Future<AuthEmailUser?> reloadUser() async {
    return _from(await _gateway.reloadAuthUser());
  }

  @override
  Future<AccountSnapshot?> snapshot({
    required String email,
    required String policyVersion,
  }) {
    return _gateway.refreshAfterEmailProof(
      email: email,
      policyVersion: policyVersion,
    );
  }

  AuthEmailUser? _from(User? user) {
    if (user == null) {
      return null;
    }
    return AuthEmailUser(
      id: user.id,
      email: user.email,
      emailConfirmedAt: user.emailConfirmedAt,
      newEmail: user.newEmail,
    );
  }
}
