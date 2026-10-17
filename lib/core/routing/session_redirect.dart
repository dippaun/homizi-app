import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/session/session_state.dart';

/// Client-side route guard. This never replaces Row Level Security.
String? sessionRedirect({
  required SessionPhase phase,
  required String location,
  required bool hasConsent,
}) {
  final path = _pathOnly(location);
  if (RoutePaths.publicLegal.contains(path)) {
    return null;
  }
  switch (phase) {
    case SessionPhase.booting:
      return path == RoutePaths.splash ? null : RoutePaths.splash;
    case SessionPhase.signedOut:
      if (path == RoutePaths.splash) {
        return hasConsent ? RoutePaths.login : RoutePaths.welcome;
      }
      if (!hasConsent) {
        return path == RoutePaths.welcome ? null : RoutePaths.welcome;
      }
      if (path == RoutePaths.welcome || path == RoutePaths.login) {
        return null;
      }
      return RoutePaths.login;
    case SessionPhase.needsConsent:
      return path == RoutePaths.welcome ? null : RoutePaths.welcome;
    case SessionPhase.needsRole:
      return path == RoutePaths.role ? null : RoutePaths.role;
    case SessionPhase.ready:
      const authOnly = {
        RoutePaths.splash,
        RoutePaths.welcome,
        RoutePaths.login,
        RoutePaths.role,
      };
      return authOnly.contains(path) ? RoutePaths.explore : null;
  }
}

String _pathOnly(String location) {
  final query = location.indexOf('?');
  if (query == -1) {
    return location;
  }
  return location.substring(0, query);
}
