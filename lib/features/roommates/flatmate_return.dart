import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/routing/route_paths.dart';

/// Roommate brief opened after sign-in from "Create profile".
const flatmateProfileNext = '${RoutePaths.requirement}?kind=roommate';

/// Where a signed-out flatmate should land once the session is ready.
final flatmateReturnProvider =
    NotifierProvider<FlatmateReturnController, String?>(
      FlatmateReturnController.new,
    );

class FlatmateReturnController extends Notifier<String?> {
  @override
  String? build() => null;

  void setPath(String? value) {
    state = safeFlatmateReturn(value);
  }

  void clear() {
    state = null;
  }
}

bool flatmateAuthGate(String path) {
  return path == RoutePaths.splash ||
      path == RoutePaths.welcome ||
      path == RoutePaths.login ||
      path == RoutePaths.role;
}

bool flatmateProfileTarget(Uri uri) {
  return uri.path == RoutePaths.requirement &&
      uri.queryParameters['kind'] == 'roommate';
}

/// Only flatmate screens. Anything else is dropped so a link cannot leave the app.
String? safeFlatmateReturn(String? next) {
  if (next == null || next.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(next);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) {
    return null;
  }
  if (flatmateProfileTarget(uri) ||
      uri.path == RoutePaths.roommates ||
      uri.path.startsWith('/flatmate/')) {
    return uri.toString();
  }
  return null;
}
