import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/account_prompt.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/profile/profile_me_screen.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _Tile {
  const _Tile({
    required this.id,
    required this.label,
    required this.icon,
    this.kind,
  });

  final String id;
  final String label;
  final IconData icon;
  final ServiceKind? kind;
}

const _primaryServices = <_Tile>[
  _Tile(
    id: 'painting',
    label: 'Painting',
    icon: Icons.format_paint_outlined,
    kind: ServiceKind.painting,
  ),
  _Tile(
    id: 'packers',
    label: 'Packers & Movers',
    icon: Icons.local_shipping_outlined,
    kind: ServiceKind.packersMovers,
  ),
  _Tile(
    id: 'cleaning',
    label: 'Home Cleaning',
    icon: Icons.cleaning_services_outlined,
    kind: ServiceKind.cleaning,
  ),
  _Tile(
    id: 'ac',
    label: 'AC Repair',
    icon: Icons.ac_unit,
    kind: ServiceKind.acRepair,
  ),
  _Tile(
    id: 'appliance',
    label: 'Appliance Service',
    icon: Icons.kitchen_outlined,
  ),
];

const _moreServices = <_Tile>[
  _Tile(
    id: 'plumbing',
    label: 'Plumbing',
    icon: Icons.plumbing,
    kind: ServiceKind.plumbing,
  ),
  _Tile(
    id: 'electrician',
    label: 'Electrician',
    icon: Icons.electrical_services_outlined,
    kind: ServiceKind.electrician,
  ),
  _Tile(
    id: 'carpentry',
    label: 'Carpentry',
    icon: Icons.carpenter_outlined,
    kind: ServiceKind.carpentry,
  ),
  _Tile(id: 'pest', label: 'Pest control', icon: Icons.pest_control_outlined),
];

/// Signed-out profile opens More. A ready session opens the profile dashboard.
class ProfileEntry extends ConsumerWidget {
  const ProfileEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ready = ref.watch(sessionProvider).phase == SessionPhase.ready;
    if (ready) {
      return const ProfileMeScreen();
    }
    return const MoreScreen();
  }
}

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  var _expanded = false;
  var _exampleNoted = false;

  void _openTile(_Tile tile) {
    final kind = tile.kind;
    if (kind != null) {
      context.push('${RoutePaths.serviceRequest}?kind=${kind.wire}');
      return;
    }
    context.push('${RoutePaths.serviceInfo}?id=${tile.id}');
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(sessionProvider).hasAccount;
    return Scaffold(
      key: const Key('more-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'More')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _BannerCard(
            cardKey: const Key('more-login'),
            color: HomiziColors.brandDarkRed,
            ink: HomiziColors.white,
            icon: Icons.person_outline,
            title: signedIn ? 'Your account' : 'Login / Sign Up',
            subtitle: signedIn
                ? 'Open your profile'
                : 'Browse first. Sign in when you want an account.',
            onTap: () {
              if (signedIn) {
                context.push(RoutePaths.profileMe);
              } else {
                context.push(signInReturn(RoutePaths.more));
              }
            },
          ),
          const SizedBox(height: 12),
          _BannerCard(
            cardKey: const Key('more-post'),
            color: HomiziColors.white,
            ink: HomiziColors.ink,
            icon: Icons.home_work_outlined,
            title: 'Post Your Property',
            subtitle: 'List your property and reach verified tenants',
            badge: 'FREE',
            onTap: () => openAccountPath(
              context,
              ref.read(sessionProvider),
              RoutePaths.listStart,
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: HomiziColors.accentWash,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              key: const Key('more-banner'),
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() => _exampleNoted = true);
                context.push(
                  '${RoutePaths.serviceRequest}?kind=${ServiceKind.cleaning.wire}',
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: const Key('more-banner-example'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: HomiziColors.brandDarkRed,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        homiziText(context, 'Example only'),
                        style: const TextStyle(
                          color: HomiziColors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      homiziText(
                        context,
                        'Because Your Home Deserves The Best.',
                      ),
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: HomiziColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      homiziText(
                        context,
                        'Example: FLAT 15% OFF summer home services. This is not a live discount and not a price.',
                      ),
                      style: const TextStyle(color: HomiziColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      homiziText(context, 'Book now'),
                      style: const TextStyle(
                        color: HomiziColors.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (_exampleNoted)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          homiziText(
                            context,
                            'The 15% line is an example. The request does not apply a discount.',
                          ),
                          style: const TextStyle(color: HomiziColors.inkSoft),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _ServiceRow(tiles: _primaryServices, onOpen: _openTile),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('more-services-expand'),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: HomiziColors.ink,
              ),
              label: Text(
                homiziText(
                  context,
                  _expanded ? 'Show fewer services' : '+4 More Services',
                ),
              ),
            ),
          ),
          if (_expanded) _ServiceRow(tiles: _moreServices, onOpen: _openTile),
          const SizedBox(height: 8),
          _RowLink(
            rowKey: const Key('more-my-services'),
            icon: Icons.home_repair_service_outlined,
            title: 'My Services',
            subtitle: 'Requests you have sent',
            onTap: () => context.push(RoutePaths.myServices),
          ),
          _RowLink(
            rowKey: const Key('more-residential'),
            icon: Icons.apartment_outlined,
            title: 'Residential Plans',
            subtitle: 'Ask about a home plan. No fee is quoted here.',
            onTap: () => context.push('${RoutePaths.plans}/residential'),
          ),
          _RowLink(
            rowKey: const Key('more-commercial'),
            icon: Icons.domain_outlined,
            title: 'Commercial Plans',
            subtitle: 'Ask about a workspace plan. No fee is quoted here.',
            onTap: () => context.push('${RoutePaths.plans}/commercial'),
          ),
          _RowLink(
            rowKey: const Key('more-help'),
            icon: Icons.support_agent_outlined,
            title: 'Help & Support',
            subtitle: 'Questions, safety, and contact',
            onTap: () => context.push(RoutePaths.help),
          ),
          _RowLink(
            rowKey: const Key('more-about'),
            icon: Icons.info_outline,
            title: 'About Homizi',
            subtitle: 'What this app is for',
            onTap: () => context.push(RoutePaths.about),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.cardKey,
    required this.color,
    required this.ink,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final Key cardKey;
  final Color color;
  final Color ink;
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: cardKey,
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: color == HomiziColors.white
                ? Border.all(color: HomiziColors.line)
                : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, title),
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      homiziText(context, subtitle),
                      style: TextStyle(
                        color: ink == HomiziColors.white
                            ? HomiziColors.white
                            : HomiziColors.inkSoft,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: HomiziColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    homiziText(context, badge!),
                    style: const TextStyle(
                      color: HomiziColors.onSuccess,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              Icon(Icons.chevron_right, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.tiles, required this.onOpen});

  final List<_Tile> tiles;
  final ValueChanged<_Tile> onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tile in tiles)
          Expanded(
            child: InkWell(
              key: Key('more-service-${tile.id}'),
              onTap: () => onOpen(tile),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                child: Column(
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        color: HomiziColors.soft,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(tile.icon, color: HomiziColors.accent),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      homiziText(context, tile.label),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: HomiziColors.ink,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _RowLink extends StatelessWidget {
  const _RowLink({
    required this.rowKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Key rowKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: rowKey,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: HomiziColors.accent),
      title: Text(
        homiziText(context, title),
        style: const TextStyle(
          fontWeight: FontWeight.w800,
          color: HomiziColors.ink,
        ),
      ),
      subtitle: Text(homiziText(context, subtitle)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
