/// Decides what to do with a stored Supabase session.
///
/// The access token and refresh token are never passed in. Callers only
/// report whether a session exists, when it expires, and whether a refresh
/// token is present. Nothing in this file is written to logs.
enum SessionRecovery { keep, refresh, signOut }

/// Refresh when the access token expires within this many seconds.
const sessionRefreshLeadSeconds = 60;

SessionRecovery sessionRecovery({
  required bool hasSession,
  required int? expiresAtUnix,
  required bool hasRefreshToken,
  required int nowUnix,
}) {
  if (!hasSession) {
    return SessionRecovery.signOut;
  }
  if (expiresAtUnix == null) {
    return SessionRecovery.keep;
  }
  final remaining = expiresAtUnix - nowUnix;
  if (remaining > sessionRefreshLeadSeconds) {
    return SessionRecovery.keep;
  }
  if (hasRefreshToken) {
    return SessionRecovery.refresh;
  }
  return SessionRecovery.signOut;
}
