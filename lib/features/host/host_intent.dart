import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/routing/route_paths.dart';

/// Where a host should land after sign-in, and where profile save returns.
class HostIntent {
  const HostIntent({this.afterAuth, this.afterProfile});

  final String? afterAuth;
  final String? afterProfile;

  HostIntent copyWith({
    String? afterAuth,
    String? afterProfile,
    bool clearAuth = false,
    bool clearProfile = false,
  }) {
    return HostIntent(
      afterAuth: clearAuth ? null : (afterAuth ?? this.afterAuth),
      afterProfile: clearProfile ? null : (afterProfile ?? this.afterProfile),
    );
  }
}

class HostIntentController extends Notifier<HostIntent> {
  @override
  HostIntent build() => const HostIntent();

  void remember(String afterAuth, {String? afterProfile}) {
    final safe = hostResumePath(afterAuth);
    if (safe == null) {
      return;
    }
    final back = afterProfile == null ? null : hostResumePath(afterProfile);
    state = HostIntent(
      afterAuth: safe,
      afterProfile: back ?? state.afterProfile,
    );
  }

  void consumeAuth() {
    state = state.copyWith(clearAuth: true);
  }

  void clearReturn() {
    state = state.copyWith(clearProfile: true);
  }
}

final hostIntentProvider = NotifierProvider<HostIntentController, HostIntent>(
  HostIntentController.new,
);

/// Paths the sign-in screen may resume. Anything else is ignored.
String? hostResumePath(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final path = raw.split('?').first;
  const allowed = {
    RoutePaths.home,
    RoutePaths.hostHome,
    RoutePaths.hostOptions,
    RoutePaths.hostSeekers,
    RoutePaths.hostLeads,
    RoutePaths.hostVisits,
    RoutePaths.hostProfile,
    RoutePaths.hostOnboard,
    RoutePaths.ownerDashboard,
    RoutePaths.ownerOverview,
    RoutePaths.forOwners,
    RoutePaths.listingEditor,
    RoutePaths.photoManager,
    RoutePaths.listings,
    RoutePaths.matches,
    RoutePaths.discover,
    RoutePaths.seekers,
    RoutePaths.profile,
    RoutePaths.verifyIdentity,
    RoutePaths.settings,
    RoutePaths.notifications,
    RoutePaths.help,
    RoutePaths.explore,
  };
  if (!allowed.contains(path)) {
    return null;
  }
  return path;
}
