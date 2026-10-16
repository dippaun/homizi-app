/// Custom-scheme callback used only when a phone opens a link in a staging email.
///
/// Android registers this as a VIEW intent (`scheme` + `host`). iOS registers
/// the scheme. The Supabase dashboard must list the same URL under
/// Authentication, URL Configuration, Redirect URLs. The web app does not use
/// this URL. A typed email code and the staging test login never send it.
const magicLinkRedirect = 'in.homizi.app://login-callback';

/// Password sign-up on a phone still emails [magicLinkRedirect].
///
/// Web sign-up omits the redirect so the browser is not sent to
/// `in.homizi.app://`. Email OTP and the staging test login do not call this.
String? passwordSignupRedirect({required bool isWeb}) {
  if (isWeb) {
    return null;
  }
  return magicLinkRedirect;
}
