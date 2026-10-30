import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

/// Path chosen on the splash search start. The router opens it once the
/// demo session is ready.
class SplashChoice extends Notifier<String?> {
  @override
  String? build() => null;

  void choose(String path) => state = path;
}

final splashDestinationProvider = NotifierProvider<SplashChoice, String?>(
  SplashChoice.new,
);

class _Branch {
  const _Branch({
    required this.branchKey,
    required this.title,
    required this.detail,
    required this.path,
    required this.image,
    required this.icon,
  });

  final Key branchKey;
  final String title;
  final String detail;
  final String path;
  final String image;
  final IconData icon;
}

const _branches = <_Branch>[
  _Branch(
    branchKey: Key('splash-path-tenant'),
    title: 'Tenant',
    detail: 'Full room, shared room, or a roommate',
    path: RoutePaths.flowTenant,
    image: 'assets/images/home/apartment.webp',
    icon: Icons.apartment,
  ),
  _Branch(
    branchKey: Key('splash-path-owner'),
    title: 'Owner',
    detail: 'Flat listing and finding. Swipe seeker demand',
    path: '${RoutePaths.flowSwipe}?deck=demand',
    image: 'assets/images/home/house.webp',
    icon: Icons.house_outlined,
  ),
  _Branch(
    branchKey: Key('splash-path-roomie'),
    title: 'Random Roommate Finder',
    detail: 'Find Your Roomie, then swipe people',
    path: RoutePaths.roomie,
    image: 'assets/images/home/roomies.jpg',
    icon: Icons.groups_outlined,
  ),
  _Branch(
    branchKey: Key('splash-path-broker'),
    title: 'Broker',
    detail: 'Post a flat, then match it',
    path: RoutePaths.flowBroker,
    image: 'assets/photos/exterior_01.webp',
    icon: Icons.real_estate_agent_outlined,
  ),
];

/// Search start. Four paths, one screen, no back control.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  var _opening = false;
  String? _error;

  Future<void> _signIn() async {
    if (_opening) {
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      await ref.read(analyticsGatewayProvider).log('app_open');
      await ref.read(sessionProvider.notifier).finishBoot();
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _opening = false;
        _error = 'Could not open sign-in. Try again.';
      });
    }
  }

  Future<void> _open(String path) async {
    if (_opening) {
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    ref.read(splashDestinationProvider.notifier).choose(path);
    try {
      try {
        await ref.read(analyticsGatewayProvider).log('app_open');
      } on Object {
        // Analytics must never block opening a Search path.
      }
      await ref
          .read(sessionProvider.notifier)
          .openSplashDemo(roleWire: roleWireForSplashPath(path));
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _opening = false;
        _error = 'Could not open the demo. Try again.';
      });
      return;
    }
    if (!mounted) {
      return;
    }
    if (ref.read(sessionProvider).phase == SessionPhase.ready) {
      context.go(path);
      return;
    }
    setState(() {
      _opening = false;
      _error = 'Could not open the demo. Try again.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('splash-search'),
      backgroundColor: HomiziColors.white,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
            children: [
              const HomiziSquareMark(size: 56),
              const SizedBox(height: 16),
              Text(
                homiziText(context, 'HOMIZI'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                homiziText(context, 'Search'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                homiziText(
                  context,
                  'Rent a room, find a flatmate, or list a home.',
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.35,
                  color: HomiziColors.inkSoft,
                ),
              ),
              if (_opening) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(color: HomiziColors.accent),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  homiziText(context, _error!),
                  style: const TextStyle(color: HomiziColors.error),
                ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('splash-sign-in'),
                  onPressed: _opening ? null : _signIn,
                  child: Text(homiziText(context, 'Sign in')),
                ),
              ),
              for (var i = 0; i < _branches.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _BranchTile(
                  branch: _branches[i],
                  onTap: _opening ? null : () => _open(_branches[i].path),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchTile extends StatelessWidget {
  const _BranchTile({required this.branch, required this.onTap});

  final _Branch branch;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: branch.branchKey,
          onTap: onTap,
          child: SizedBox(
            height: 112,
            child: Row(
              children: [
                SizedBox(
                  width: 112,
                  height: 112,
                  child: Image.asset(
                    branch.image,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stackTrace) =>
                        const ColoredBox(color: HomiziColors.mist),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(branch.icon, color: HomiziColors.accent, size: 20),
                      const SizedBox(height: 4),
                      Text(
                        homiziText(context, branch.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: HomiziColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        homiziText(context, branch.detail),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          height: 1.3,
                          color: HomiziColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.chevron_right, color: HomiziColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Maps a splash Search destination to `profiles.primary_role` wire.
String roleWireForSplashPath(String path) {
  final base = path.split('?').first;
  if (base == RoutePaths.roomie) {
    return 'roommate';
  }
  if (base == RoutePaths.flowBroker) {
    return 'broker';
  }
  if (base == RoutePaths.flowSwipe || path.contains('deck=demand')) {
    return 'host';
  }
  return 'tenant';
}
