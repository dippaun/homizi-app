/// How a mobile code is delivered.
///
/// SMS is the channel that is sent. WhatsApp stays in the client until a
/// WhatsApp Business sender exists, and it is off unless
/// `--dart-define=PHONE_WHATSAPP_OTP=true`.
enum PhoneOtpChannel { whatsapp, sms }

/// Raw `--dart-define=PHONE_WHATSAPP_OTP`. Empty means off.
const phoneWhatsappOtpDefine = String.fromEnvironment('PHONE_WHATSAPP_OTP');

/// True only for a build that sets `PHONE_WHATSAPP_OTP` to `true`.
bool get phoneWhatsappOtp => phoneWhatsappOtpDefine == 'true';

/// Channel actually requested. WhatsApp is ignored while the flag is off.
PhoneOtpChannel phoneDeliveryChannel(PhoneOtpChannel requested) {
  if (!phoneWhatsappOtp && requested == PhoneOtpChannel.whatsapp) {
    return PhoneOtpChannel.sms;
  }
  return requested;
}
