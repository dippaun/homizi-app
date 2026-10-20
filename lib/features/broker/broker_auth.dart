import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/session/session_state.dart';

/// True for `/broker` and everything under it. Rejects `..` so a query
/// cannot walk off this area.
bool isBrokerArea(String path) {
  if (path.contains('..')) {
    return false;
  }
  return path == RoutePaths.brokerHome ||
      path.startsWith('${RoutePaths.brokerHome}/');
}

/// Login URL that returns to the broker profile, then [back].
String brokerProfileSignInLocation({String back = RoutePaths.home}) {
  return Uri(
    path: RoutePaths.login,
    queryParameters: {'next': RoutePaths.brokerRegister, 'back': back},
  ).toString();
}

/// Keeps a broker profile request alive across sign-in.
///
/// Signed-out visits to a broker path go to login with `next` set.
/// After the session is ready, or still needs a role, that `next` opens
/// the profile instead of the generic home. A broker path is also allowed
/// while the role is still unset, so the profile can save it.
String? brokerReturnRedirect({
  required String? decided,
  required SessionPhase phase,
  required String path,
  required Map<String, String> query,
}) {
  final next = _brokerTarget(query['next']);
  final back = _backTarget(query['back']);

  if (phase == SessionPhase.needsRole && isBrokerArea(path)) {
    return null;
  }
  if (phase == SessionPhase.signedOut && path == RoutePaths.role) {
    if (decided == RoutePaths.login) {
      return null;
    }
    return decided;
  }
  if (phase == SessionPhase.signedOut && isBrokerArea(path)) {
    if (decided != null && decided != RoutePaths.login) {
      return decided;
    }
    return _loginFor(path, back: back ?? RoutePaths.home);
  }
  if (phase == SessionPhase.ready && path == RoutePaths.brokerHome) {
    return RoutePaths.home;
  }
  final leavingAuth =
      path == RoutePaths.login ||
      path == RoutePaths.role ||
      path == RoutePaths.splash ||
      path == RoutePaths.welcome;
  if (next != null &&
      leavingAuth &&
      (phase == SessionPhase.ready || phase == SessionPhase.needsRole)) {
    return _withBack(next, back);
  }
  return decided;
}

String? _brokerTarget(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final path = raw.split('?').first;
  if (!path.startsWith('/') || !isBrokerArea(path)) {
    return null;
  }
  return path;
}

String? _backTarget(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final path = raw.split('?').first;
  if (!path.startsWith('/') || path.contains('..')) {
    return null;
  }
  const allowed = <String>{
    RoutePaths.home,
    RoutePaths.welcome,
    RoutePaths.role,
    RoutePaths.login,
  };
  if (allowed.contains(path) || isBrokerArea(path)) {
    return path;
  }
  return null;
}

String _loginFor(String path, {required String back}) {
  return Uri(
    path: RoutePaths.login,
    queryParameters: {'next': path, 'back': back},
  ).toString();
}

String _withBack(String path, String? back) {
  if (back == null) {
    return path;
  }
  return Uri(path: path, queryParameters: {'back': back}).toString();
}
