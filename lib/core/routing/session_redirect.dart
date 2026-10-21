import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/session/session_state.dart';

/// Staging web never shows the sign-in screen. Other builds are unchanged.
bool stagingWebSkipsLogin(AppConfig config, {required bool isWeb}) {
  return isWeb && config.environment == AppEnvironment.staging;
}

/// Client-side route guard. This never replaces Row Level Security.
///
/// [demoSkipLogin] holds launch routes on the splash screen until the demo
/// session opens that role's home. [skipLogin] is the staging web build when
/// that flag is off. It never returns the sign-in route. Launch paths go to
/// the role chooser. Any other path that would have gone to sign-in stays.
String? sessionRedirect({
  required SessionPhase phase,
  required String location,
  required bool hasConsent,
  String? resume,
  bool demoSkipLogin = false,
  bool skipLogin = false,
}) {
  final path = _pathOnly(location);
  if (RoutePaths.publicLegal.contains(path)) {
    return null;
  }
  // Create-profile keeps a local draft and must not bounce to sign-in.
  if (path == RoutePaths.profileCreate) {
    return null;
  }
  switch (phase) {
    case SessionPhase.booting:
      return path == RoutePaths.splash ? null : RoutePaths.splash;
    case SessionPhase.signedOut:
      if (demoSkipLogin) {
        return path == RoutePaths.splash ? null : RoutePaths.splash;
      }
      if (skipLogin) {
        return _demoLaunchOrStay(path, resume: resume);
      }
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
      if (demoSkipLogin) {
        return path == RoutePaths.splash ? null : RoutePaths.splash;
      }
      if (skipLogin) {
        return _demoLaunchOrStay(path, resume: resume);
      }
      return path == RoutePaths.welcome ? null : RoutePaths.welcome;
    case SessionPhase.needsRole:
      if (demoSkipLogin) {
        return path == RoutePaths.splash ? null : RoutePaths.splash;
      }
      if (skipLogin && !_launchPath(path)) {
        return null;
      }
      return path == RoutePaths.role ? null : RoutePaths.role;
    case SessionPhase.ready:
      const authOnly = {
        RoutePaths.splash,
        RoutePaths.welcome,
        RoutePaths.login,
      };
      if (!authOnly.contains(path)) {
        return null;
      }
      if (resume != null && resume.isNotEmpty) {
        return resume;
      }
      return RoutePaths.home;
  }
}

String _pathOnly(String location) {
  final query = location.indexOf('?');
  if (query == -1) {
    return location;
  }
  return location.substring(0, query);
}

/// True for the screens a cold start can sit on before a role is chosen.
bool _launchPath(String path) {
  return path.isEmpty ||
      path == '/' ||
      path == RoutePaths.splash ||
      path == RoutePaths.welcome ||
      path == RoutePaths.login;
}

String? _demoLaunchOrStay(String path, {String? resume}) {
  if (!_launchPath(path)) {
    return null;
  }
  if (path == RoutePaths.login && resume != null && resume.isNotEmpty) {
    return resume;
  }
  return RoutePaths.role;
}

/// Last step for staging web. [decided] may still be `/login` when a feature
/// redirect built that URL itself. Launch goes to the role chooser. A `next`
/// query, or the page that was open, is the destination.
String? avoidLoginRedirect({
  required String? decided,
  required String path,
  required Map<String, String> query,
}) {
  final decidedUri = decided == null ? null : Uri.tryParse(decided);
  final decidedPath = decidedUri?.path;
  final toLogin = decidedPath == RoutePaths.login || path == RoutePaths.login;
  if (!toLogin) {
    return decided;
  }
  final next = _safeInternal(
    query['next'] ?? decidedUri?.queryParameters['next'],
  );
  if (next != null) {
    return next;
  }
  if (decidedPath != null &&
      decidedPath != RoutePaths.login &&
      decidedPath != RoutePaths.role) {
    return decided;
  }
  if (!_launchPath(path)) {
    return null;
  }
  return RoutePaths.role;
}

String? _safeInternal(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) {
    return null;
  }
  final path = uri.path;
  if (!path.startsWith('/') ||
      path.contains('..') ||
      path == RoutePaths.login) {
    return null;
  }
  if (path == RoutePaths.welcome || path == RoutePaths.splash || path == '/') {
    return null;
  }
  if (!uri.hasQuery) {
    return path;
  }
  return '$path?${uri.query}';
}
