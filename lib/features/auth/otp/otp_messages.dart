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

const emailRateLimitMessage =
    'Supabase rate limit: too many emails were sent. Wait a few minutes and try again. No new message was sent.';

/// Shown for `over_email_send_rate_limit`. The Supabase code is not included.
const emailSendRateLimitMessage =
    'Too many codes were requested. Please wait a few minutes and try again.';

const googleOpeningMessage = 'Opening Google…';

const googleRetryMessage = 'Google did not open. Try again.';

const mobileVerificationSoonMessage = 'Mobile verification is coming soon';

const smsRateLimitMessage =
    'Supabase rate limit: too many text messages were sent. Wait a few minutes and try again. No new message was sent.';
