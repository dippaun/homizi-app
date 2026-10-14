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
  });

  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Consent text version recorded on the welcome screen.
  final String policyVersion;

  /// A hosted or local Supabase project is used only when both values exist.
  bool get connectsToSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// The development OTP is refused in prod so a release build has no backdoor.
  bool get allowsDevOtp => environment != AppEnvironment.prod;

  /// Staging against the hosted project sends an email code.
  /// Phone SMS stays off. Demo mode and local dev keep the on-device code.
  bool get usesHostedEmailOtp =>
      environment == AppEnvironment.staging && connectsToSupabase;

  static const devOtp = '000000';

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

  factory AppConfig.fromDefines() {
    final publishable = _rawPublishableKey.trim();
    final anon = _rawAnonKey.trim();
    return AppConfig.parse(
      rawEnvironment: _rawEnvironment,
      supabaseUrl: _rawUrl,
      supabaseAnonKey: publishable.isNotEmpty ? publishable : anon,
      policyVersion: _rawPolicy,
    );
  }

  factory AppConfig.parse({
    required String rawEnvironment,
    required String supabaseUrl,
    required String supabaseAnonKey,
    required String policyVersion,
  }) {
    final key = supabaseAnonKey.trim();
    if (key.startsWith('sb_secret_') ||
        key.toLowerCase().contains('service_role')) {
      throw const FormatException(
        'The Supabase client key must be the public publishable key.',
      );
    }
    return AppConfig(
      environment: parseEnvironment(rawEnvironment),
      supabaseUrl: supabaseUrl.trim(),
      supabaseAnonKey: key,
      policyVersion: policyVersion.trim().isEmpty
          ? '2026-10-11-draft'
          : policyVersion.trim(),
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
