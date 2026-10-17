/// Runtime configuration. Values come from `--dart-define` or
/// `--dart-define-from-file` (see README). Nothing here is a secret store:
/// the anon key is a public client key, and an empty pair means demo mode.
enum AppEnvironment { dev, staging, prod }

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.policyVersion,
    this.stagingPasswordAuth = false,
    this.stagingTestPassword = '',
    this.sentryDsn = '',
  });

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Consent text version recorded on the welcome screen.
  final String policyVersion;

  /// Staging-only email and password sign-up. Ignored outside staging.
  final bool stagingPasswordAuth;

  /// Password for the throwaway mailbox [stagingTestEmail].
  /// [parse] stores this only when [environment] is staging. A production
  /// build keeps it empty, so the test login cannot run.
  final String stagingTestPassword;

  /// Empty unless the build was compiled with `SENTRY_DSN`. Error reporting
  /// stays off for every other build. This value is not a Supabase key.
  final String sentryDsn;

  /// A hosted or local Supabase project is used only when both values exist.
  bool get connectsToSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// The development OTP is refused in prod so a release build has no backdoor.
  bool get allowsDevOtp => environment != AppEnvironment.prod;

  /// Staging against the hosted project emails a 6-digit code.
  /// A link in that email is only a fallback. Phone SMS stays off.
  /// Demo mode and local dev keep the on-device code.
  bool get usesHostedEmailOtp =>
      environment == AppEnvironment.staging && connectsToSupabase;

  /// Email and password on the hosted staging project. Production ignores the flag.
  bool get allowsStagingPassword =>
      environment == AppEnvironment.staging &&
      connectsToSupabase &&
      stagingPasswordAuth;

  /// Throwaway staging sign-in for [stagingTestEmail] with [stagingTestCode].
  /// Production is false because [stagingTestPassword] is cleared outside staging.
  bool get allowsStagingTestLogin =>
      environment == AppEnvironment.staging &&
      connectsToSupabase &&
      stagingTestPassword.isNotEmpty;

  bool get reportsErrors => sentryDsn.trim().isNotEmpty;

  /// The "ID verified (demo)" switch. Staging builds show it. Demo mode
  /// (no project connected) shows it so the badge can be tried offline.
  /// Production never shows it. The server only flips a mock status.
  bool get showsDemoIdBadge {
    if (environment == AppEnvironment.prod) {
      return false;
    }
    if (environment == AppEnvironment.staging) {
      return true;
    }
    return !connectsToSupabase;
  }

  static const devOtp = '000000';

  /// Throwaway staging mailbox. Production never signs in as this address
  /// with [stagingTestCode].
  static const stagingTestEmail = 'test@homizi.in';

  /// Code that selects the staging test password. It is not accepted as a
  /// hosted email OTP, and production ignores it.
  static const stagingTestCode = '000000';

  static const _rawEnvironment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );
  static const _rawUrl = String.fromEnvironment('SUPABASE_URL');
  static const _rawAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _rawPublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );
  static const _rawPolicy = String.fromEnvironment(
    'POLICY_VERSION',
    defaultValue: '2026-10-11-draft',
  );
  static const _rawStagingPassword = String.fromEnvironment(
    'STAGING_PASSWORD_AUTH',
  );
  static const _rawStagingTestPassword = String.fromEnvironment(
    'STAGING_TEST_PASSWORD',
  );
  static const _rawSentryDsn = String.fromEnvironment('SENTRY_DSN');

  factory AppConfig.fromDefines() {
    final publishable = _rawPublishableKey.trim();
    final anon = _rawAnonKey.trim();
    return AppConfig.parse(
      rawEnvironment: _rawEnvironment,
      supabaseUrl: _rawUrl,
      supabaseAnonKey: publishable.isNotEmpty ? publishable : anon,
      policyVersion: _rawPolicy,
      stagingPasswordAuth: _rawStagingPassword.trim().toLowerCase() == 'true',
      // The define is empty in analysis, and non-empty only in a compiled build.
      // ignore: avoid_redundant_argument_values
      stagingTestPassword: _rawStagingTestPassword,
      // ignore: avoid_redundant_argument_values
      sentryDsn: _rawSentryDsn,
    );
  }

  factory AppConfig.parse({
    required String rawEnvironment,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String policyVersion,
    bool stagingPasswordAuth = false,
    String stagingTestPassword = '',
    String sentryDsn = '',
  }) {
    final key = supabaseAnonKey.trim();
    if (key.startsWith('sb_secret_') ||
        key.toLowerCase().contains('service_role')) {
      throw const FormatException(
        'The Supabase client key must be the public publishable key.',
      );
    }
    final environment = parseEnvironment(rawEnvironment);
    return AppConfig(
      environment: environment,
      supabaseUrl: supabaseUrl.trim(),
      supabaseAnonKey: key,
      policyVersion: policyVersion.trim().isEmpty
          ? '2026-10-11-draft'
          : policyVersion.trim(),
      stagingPasswordAuth: stagingPasswordAuth,
      // Production, dev, and demo builds drop the throwaway password.
      stagingTestPassword: environment == AppEnvironment.staging
          ? stagingTestPassword.trim()
          : '',
      sentryDsn: sentryDsn.trim(),
    );
  }

  static AppEnvironment parseEnvironment(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'dev':
      case 'development':
        return AppEnvironment.dev;
      case 'staging':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
        return AppEnvironment.prod;
      default:
        throw FormatException(
          'Unknown APP_ENV "$raw". Use dev, staging, or prod.',
        );
    }
  }
}
