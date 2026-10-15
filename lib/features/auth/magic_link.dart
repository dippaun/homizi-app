/// Custom-scheme callback for the staging magic link.
///
/// Android registers this as a VIEW intent (`scheme` + `host`). iOS registers
/// the scheme. The Supabase dashboard must list the same URL under
/// Authentication, URL Configuration, Redirect URLs.
const magicLinkRedirect = 'in.homizi.app://login-callback';
