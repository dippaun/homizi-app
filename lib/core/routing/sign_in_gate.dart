import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/find_roomie/find_roomie_paths.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shell/min_touch.dart';

/// Where sign-in should return when the login URL loses its query.
///
/// Welcome drops unknown queries. The gate remembers the private screen so
/// a successful sign-in can still open it. This is not an auth source.
class SignInReturnPath extends Notifier<String?> {
  @override
  String? build() => null;

  void remember(String location) {
    final safe = signInResumeTarget(location);
    state = safe;
  }

  void clear() => state = null;
}

final signInReturnPathProvider = NotifierProvider<SignInReturnPath, String?>(
  SignInReturnPath.new,
);

/// Chats, saved homes, profile, and the other account screens.
///
/// Home, search, a listing, Priorities, and the Roommate tab stay public.
bool isPrivateScreen(String location) {
  final path = location.split('?').first;
  if (path == RoutePaths.chats || path.startsWith('${RoutePaths.chats}/')) {
    return true;
  }
  if (RegExp(r'^/matches/[^/]+/chat$').hasMatch(path)) {
    return true;
  }
  const exact = {
    RoutePaths.matches,
    RoutePaths.saved,
    RoutePaths.savedSearches,
    RoutePaths.recentlyViewed,
    RoutePaths.notifications,
    RoutePaths.flatmateMutual,
    RoutePaths.profile,
    RoutePaths.profileMe,
    RoutePaths.profileInquiries,
    RoutePaths.tenantProfile,
    RoutePaths.hostProfile,
    RoutePaths.requirement,
    RoutePaths.hostLeads,
    RoutePaths.hostSeekers,
    RoutePaths.hostTopMatches,
    RoutePaths.seekers,
    RoutePaths.rentSplit,
    RoutePaths.roommateSaved,
  };
  if (exact.contains(path) || path.startsWith('${RoutePaths.seekers}/')) {
    return true;
  }
  if (path == SharedHomePaths.hostRequests) {
    return true;
  }
  if (path == FindRoomiePaths.connect || path.startsWith('/find-roomie/')) {
    return true;
  }
  return false;
}

/// Internal path from a `redirect` query. External addresses are ignored.
String? signInResumeTarget(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) {
    return null;
  }
  final path = uri.path;
  if (!path.startsWith('/') || path.contains('..') || path == '/') {
    return null;
  }
  const blocked = {
    RoutePaths.login,
    RoutePaths.loginPhone,
    RoutePaths.welcome,
    RoutePaths.splash,
  };
  if (blocked.contains(path)) {
    return null;
  }
  if (!uri.hasQuery) {
    return path;
  }
  return '$path?${uri.query}';
}

/// Login URL that opens [panel] and returns to [returnTo] after sign-in.
String signInGateLogin({required String returnTo, required bool signup}) {
  return Uri(
    path: RoutePaths.login,
    queryParameters: {
      'redirect': returnTo,
      'panel': signup ? 'signup' : 'login',
    },
  ).toString();
}

/// Shows [child] only when [signedInProvider] is true.
///
/// A signed-out private route paints the gate and does not mount [child],
/// so sample chats and other account data never enter the tree. Shell
/// branches that are not the page on screen paint nothing.
class SignInGate extends ConsumerWidget {
  const SignInGate({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = location.split('?').first;
    if (!isPrivateScreen(path) || ref.watch(signedInProvider)) {
      return child;
    }
    final router = GoRouter.maybeOf(context);
    if (router != null && router.state.uri.path != path) {
      return const SizedBox.shrink();
    }
    return SignInContinuePage(returnTo: location);
  }
}

Widget guardPrivateRoute(GoRouterState state, Widget child) {
  return SignInGate(location: state.uri.toString(), child: child);
}

/// Polished stand-in for a private screen. One back control, then Login
/// and Signup, which open the existing auth entry and come back here.
class SignInContinuePage extends ConsumerWidget {
  const SignInContinuePage({required this.returnTo, super.key});

  final String returnTo;

  void _open(BuildContext context, WidgetRef ref, {required bool signup}) {
    ref.read(signInReturnPathProvider.notifier).remember(returnTo);
    context.push(signInGateLogin(returnTo: returnTo, signup: signup));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return MinTouchScope(
      child: Scaffold(
        key: const Key('sign-in-gate'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          backgroundColor: HomiziColors.white,
          surfaceTintColor: HomiziColors.white,
          elevation: 0,
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const _GateMark(),
                const SizedBox(height: 28),
                Text(
                  homiziText(context, 'Sign in to continue'),
                  key: const Key('sign-in-gate-title'),
                  textAlign: TextAlign.center,
                  style: text.headlineSmall?.copyWith(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  homiziText(
                    context,
                    'Chats, saved homes, and your profile stay on your account. After you sign in, Homizi brings you back here.',
                  ),
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(
                    color: HomiziColors.inkSoft,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 32),
                _GradientCta(
                  buttonKey: const Key('sign-in-gate-login'),
                  label: homiziText(context, 'Login'),
                  onPressed: () => _open(context, ref, signup: false),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  key: const Key('sign-in-gate-signup'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomiziColors.ink,
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(
                      color: HomiziColors.logoOrange,
                      width: 1.5,
                    ),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                  ),
                  onPressed: () => _open(context, ref, signup: true),
                  child: Text(
                    homiziText(context, 'Signup'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GateMark extends StatelessWidget {
  const _GateMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HomiziColors.logoOrange, HomiziColors.brandRedOrange],
          ),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.lock_outline,
          color: HomiziColors.ink,
          size: 36,
        ),
      ),
    );
  }
}

class _GradientCta extends StatelessWidget {
  const _GradientCta({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [HomiziColors.logoOrange, HomiziColors.brandRedOrange],
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Material(
        color: HomiziColors.clear,
        child: InkWell(
          key: buttonKey,
          onTap: onPressed,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
