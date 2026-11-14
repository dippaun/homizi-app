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

const networkAuthMessage =
    'The connection dropped. Check your network and try again.';

const providerUnavailableMessage =
    'That sign-in option is not available yet. Continue with your email.';

const genericAuthMessage = 'That did not work. Please try again.';
