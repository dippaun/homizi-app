/// Sentences shown for email and mobile codes. No code is stored here.
const duplicatePhoneMessage =
    'This number is already linked to another Homizi account';

const duplicateEmailMessage =
    'This email is already linked to another Homizi account';

const expiredOtpMessage =
    'That code has expired. Request a new one. Check the 6 digits from the latest message.';

const incorrectOtpMessage =
    'That code is incorrect. Check the 6 digits and try again. No session was started.';

const retryCapMessage = 'Too many tries. Request a new code.';

const otpExpiryHint = 'The code expires in 5 minutes.';

const captchaRequiredMessage =
    'Complete the security check, then try again. No code was sent.';

const indianMobileInvalidMessage =
    'Enter a 10-digit mobile number starting with 6, 7, 8, or 9.';

const productionDevOtpMessage =
    'The development code is refused in production. Sign-in is not connected to an OTP provider in this build.';

/// Shown for `over_email_send_rate_limit` and an email 429.
/// The provider code is not included.
const emailSendRateLimitMessage =
    'Too many codes requested. Please wait a minute and try again.';

const emailRateLimitMessage = emailSendRateLimitMessage;

const googleOpeningMessage = 'Opening Google…';

const googleRetryMessage = 'Google did not open. Try again.';

const mobileVerificationSoonMessage = 'Mobile verification is coming soon';

const smsRateLimitMessage =
    'Too many text messages were requested. Please wait a minute and try again.';

/// Twilio trial error 21608. The sentence names the staging test number.
const phoneTrialUnverifiedMessage =
    'This number can\'t receive test SMS yet. During testing use +91 9999999999 with code 123456.';

/// Twilio Verify 60200. The provider code is not included.
const phoneInvalidParameterMessage =
    'That mobile number was not accepted. Check the 10 digits and try again.';

/// Shown when WhatsApp delivery fails and SMS is still offered.
const whatsappSendFailedMessage =
    'WhatsApp could not send the code. Send by SMS instead.';

/// Hosted phone auth is off, so neither WhatsApp nor SMS was sent.
const phoneCodesUnavailableMessage =
    'Mobile codes are not switched on yet. No code was sent.';

/// `000000` is not a phone code. The text message has the real digits.
const phoneDevCodeRefusedMessage =
    'That code is not accepted. Enter the 6-digit code from the text message.';

/// Keeps a specific Auth sentence. Other WhatsApp failures point at SMS.
String whatsappSendFailure(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty) {
    return whatsappSendFailedMessage;
  }
  const keep = <String>{
    phoneTrialUnverifiedMessage,
    phoneInvalidParameterMessage,
    duplicatePhoneMessage,
    smsRateLimitMessage,
    captchaRequiredMessage,
    indianMobileInvalidMessage,
    phoneSignInUnavailableMessage,
    phoneNotRegisteredMessage,
    productionDevOtpMessage,
    phoneCodesUnavailableMessage,
    expiredOtpMessage,
    incorrectOtpMessage,
    networkAuthMessage,
    retryCapMessage,
    phoneDemoCodeMessage,
    phoneDemoWrongCodeMessage,
  };
  if (keep.contains(trimmed)) {
    return trimmed;
  }
  final lower = trimmed.toLowerCase();
  if (lower.contains('already linked') ||
      lower.contains('not enabled yet') ||
      lower.contains('not switched on') ||
      lower.contains('too many') ||
      lower.contains('security check') ||
      lower.contains('sign in before') ||
      lower.contains('10-digit') ||
      lower.contains('not verified on a homizi')) {
    return trimmed;
  }
  return whatsappSendFailedMessage;
}

const networkAuthMessage =
    'The connection dropped. Check your network and try again.';

const providerUnavailableMessage =
    'That sign-in option is not available yet. Continue with your email.';

/// Phone provider is off, or Auth answered `phone_provider_disabled`.
const phoneSignInUnavailableMessage =
    'Mobile sign-in is not switched on for this project. No text message was sent.';

/// `shouldCreateUser: false` and Auth has no user for this number.
const phoneNotRegisteredMessage =
    'This number is not verified on a Homizi account yet. No text message was sent.';

/// Shown on the code screen when no SMS was sent. Staging and dev only.
const phoneDemoCodeMessage =
    'No text message was sent. Enter 000000 on this build.';

const phoneDemoWrongCodeMessage =
    'That code was not accepted. No text message was sent. Enter 000000 on this build.';

const genericAuthMessage = 'That did not work. Please try again.';
