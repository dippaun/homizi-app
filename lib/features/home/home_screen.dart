import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/session/session_controller.dart';

/// One-stop home for a signed-in person. Cards only open screens that already
/// exist. Orange fills are tints of the logo accent, with near-black labels.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contact = ref.watch(sessionProvider).contact;
    return Scaffold(
      key: const Key('home-screen'),
      backgroundColor: HomiziColors.white,
      drawer: const _HomeDrawer(),
      appBar: AppBar(
        titleSpacing: 4,
        leading: Builder(
          builder: (buttonContext) {
            return IconButton(
              key: const Key('home-menu'),
              tooltip: homiziText(context, 'Menu'),
              onPressed: () => Scaffold.of(buttonContext).openDrawer(),
              icon: const Icon(Icons.menu),
            );
          },
        ),
        title: const _Lockup(),
        actions: [
          IconButton(
            key: const Key('home-chat'),
            tooltip: homiziText(context, 'Chat'),
            onPressed: () => context.go(RoutePaths.matches),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          IconButton(
            key: const Key('home-profile'),
            tooltip: homiziText(context, 'Profile'),
            onPressed: () => context.push(RoutePaths.profile),
            icon: ExcludeSemantics(
              child: HostAvatar(name: _avatarName(contact), radius: 16),
            ),
          ),
        ],
      ),
      body: const _HomeBody(),
    );
  }
}

String _avatarName(String contact) {
  final local = contact.split('@').first.trim();
  if (local.isEmpty) {
    return 'You';
  }
  return local;
}

class _Lockup extends StatelessWidget {
  const _Lockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ExcludeSemantics(child: HomiziMark(size: 26)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            homiziText(context, 'HOMIZI'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _Jump {
  const _Jump({
    required this.icon,
    required this.label,
    required this.path,
    this.branch = false,
  });

  final IconData icon;
  final String label;
  final String path;
  final bool branch;
}

const _drawerJumps = <_Jump>[
  _Jump(
    icon: Icons.search,
    label: 'Find a home',
    path: RoutePaths.explore,
    branch: true,
  ),
  _Jump(
    icon: Icons.home_work_outlined,
    label: 'List your home',
    path: RoutePaths.listingEditor,
  ),
  _Jump(
    icon: Icons.style_outlined,
    label: 'Swipe to match',
    path: RoutePaths.discover,
    branch: true,
  ),
  _Jump(
    icon: Icons.handshake_outlined,
    label: 'Matches',
    path: RoutePaths.matches,
    branch: true,
  ),
  _Jump(
    icon: Icons.bookmark_outline,
    label: 'Saved',
    path: RoutePaths.saved,
    branch: true,
  ),
  _Jump(
    icon: Icons.home_repair_service_outlined,
    label: 'Home services',
    path: RoutePaths.services,
  ),
  _Jump(
    icon: Icons.handyman_outlined,
    label: 'Rent tools',
    path: RoutePaths.tools,
  ),
  _Jump(
    icon: Icons.payments_outlined,
    label: 'Pay rent',
    path: RoutePaths.payments,
  ),
  _Jump(
    icon: Icons.verified_user_outlined,
    label: 'Verify identity',
    path: RoutePaths.verifyIdentity,
  ),
  _Jump(
    icon: Icons.notifications_outlined,
    label: 'Notifications',
    path: RoutePaths.notifications,
  ),
  _Jump(icon: Icons.help_outline, label: 'Help', path: RoutePaths.help),
  _Jump(
    icon: Icons.settings_outlined,
    label: 'Settings',
    path: RoutePaths.settings,
  ),
  _Jump(icon: Icons.person_outline, label: 'Profile', path: RoutePaths.profile),
];

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context) {
    return NavigationDrawer(
      backgroundColor: HomiziColors.white,
      indicatorColor: HomiziColors.accentWash,
      selectedIndex: null,
      onDestinationSelected: (index) {
        final jump = _drawerJumps[index];
        final router = GoRouter.of(context);
        Navigator.pop(context);
        if (jump.branch) {
          router.go(jump.path);
        } else {
          router.push(jump.path);
        }
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 28, 16, 4),
          child: _Lockup(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 12),
          child: Text(
            homiziText(context, 'Your rental, in one place'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: HomiziColors.muted),
          ),
        ),
        for (final jump in _drawerJumps)
          NavigationDrawerDestination(
            icon: Icon(jump.icon),
            label: Text(
              homiziText(context, jump.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const Key('home-scroll'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Text(
          homiziText(context, 'Everything for your next home'),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Search, list, match, and settle a rental in India.',
          ),
          style: theme.textTheme.bodyLarge?.copyWith(color: HomiziColors.muted),
        ),
        const SizedBox(height: 20),
        const _FeatureGrid(),
        const SizedBox(height: 24),
        Text(
          homiziText(context, 'Home services'),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        const _ServiceRow(),
        const SizedBox(height: 20),
        const _PairRow(),
        const SizedBox(height: 12),
        _HubCard(
          cardKey: const Key('home-pay'),
          title: 'Pay rent',
          lines: const [
            'Pay a matched rent',
            'Razorpay test mode, then a receipt',
          ],
          icon: Icons.payments_outlined,
          color: HomiziColors.accent,
          onAccent: true,
          height: 132,
          onTap: () => context.push(RoutePaths.payments),
          trailing: const ExcludeSemantics(
            child: Icon(Icons.credit_card, size: 48, color: HomiziColors.ink),
          ),
        ),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 360 ? 252.0 : 276.0;
        return SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 12,
                child: _HubCard(
                  cardKey: const Key('home-find'),
                  title: 'Find a home',
                  lines: const [
                    'Published homes, rent in rupees',
                    'Locality and city, not a street',
                  ],
                  icon: Icons.search,
                  color: HomiziColors.accent,
                  onAccent: true,
                  onTap: () => context.go(RoutePaths.explore),
                  photo: 'assets/photos/exterior_01.webp',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    Expanded(
                      child: _HubCard(
                        cardKey: const Key('home-list'),
                        title: 'List your home',
                        lines: const ['Six steps, saved as you go'],
                        icon: Icons.home_work_outlined,
                        color: _Tone.clay,
                        onTap: () => context.push(RoutePaths.listingEditor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _HubCard(
                        cardKey: const Key('home-swipe'),
                        title: 'Swipe to match',
                        lines: const ['Like when it fits'],
                        icon: Icons.style_outlined,
                        color: _Tone.blush,
                        onTap: () => context.go(RoutePaths.discover),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceRow extends StatefulWidget {
  const _ServiceRow();

  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  final _scroll = ScrollController();
  var _page = 0;

  static const _cardWidth = 164.0;
  static const _gap = 12.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) {
      return;
    }
    final next = _pageIndex(
      viewport: _scroll.position.viewportDimension,
      offset: _scroll.offset,
    );
    if (next != _page) {
      setState(() => _page = next);
    }
  }

  int _pageCount(double viewport) {
    final content =
        _services.length * _cardWidth + (_services.length - 1) * _gap;
    if (viewport <= 0 || content <= viewport + 1) {
      return 1;
    }
    return ((content - viewport) / viewport).ceil() + 1;
  }

  int _pageIndex({required double viewport, required double offset}) {
    final pages = _pageCount(viewport);
    if (pages <= 1 || viewport <= 0) {
      return 0;
    }
    final index = (offset / viewport).round();
    if (index < 0) {
      return 0;
    }
    if (index > pages - 1) {
      return pages - 1;
    }
    return index;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final pages = _pageCount(constraints.maxWidth);
        final page = pages <= 1 ? 0 : _page.clamp(0, pages - 1);
        return Column(
          children: [
            SizedBox(
              height: 148,
              child: ListView.separated(
                key: const Key('home-services'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                itemCount: _services.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: _gap),
                itemBuilder: (context, index) {
                  final item = _services[index];
                  return SizedBox(
                    width: _cardWidth,
                    child: _HubCard(
                      cardKey: Key(item.keyName),
                      title: item.title,
                      lines: [item.line],
                      icon: item.icon,
                      color: index.isEven ? _Tone.mist : _Tone.blush,
                      onTap: () => context.push(item.path),
                    ),
                  );
                },
              ),
            ),
            if (pages > 1) ...[
              const SizedBox(height: 12),
              _PageDots(pages: pages, index: page),
            ],
          ],
        );
      },
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.pages, required this.index});

  final int pages;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('home-service-dots'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < pages; i++)
          Semantics(
            label: homiziText(context, 'Service page ${i + 1} of $pages'),
            selected: i == index,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: i == index ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == index ? HomiziColors.accent : HomiziColors.line,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
      ],
    );
  }
}

class _PairRow extends StatelessWidget {
  const _PairRow();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 156,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _ToolsCard()),
          SizedBox(width: 12),
          Expanded(child: _VerifyCard()),
        ],
      ),
    );
  }
}

class _ToolsCard extends StatelessWidget {
  const _ToolsCard();

  @override
  Widget build(BuildContext context) {
    return _HubCard(
      cardKey: const Key('home-tools'),
      title: 'Rent tools',
      lines: const [
        'Receipts, split, and checklist',
        'Deposit tracker included',
      ],
      icon: Icons.handyman_outlined,
      color: _Tone.blush,
      onTap: () => context.push(RoutePaths.tools),
    );
  }
}

class _VerifyCard extends StatelessWidget {
  const _VerifyCard();

  @override
  Widget build(BuildContext context) {
    return _HubCard(
      cardKey: const Key('home-verify'),
      title: 'Verify identity',
      lines: const ['Aadhaar and a face step', 'Only when you choose to'],
      icon: Icons.verified_user_outlined,
      color: _Tone.clay,
      onTap: () => context.push(RoutePaths.verifyIdentity),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.cardKey,
    required this.title,
    required this.lines,
    required this.icon,
    required this.color,
    required this.onTap,
    this.onAccent = false,
    this.photo,
    this.height,
    this.trailing,
  });

  final Key cardKey;
  final String title;
  final List<String> lines;
  final IconData icon;
  final Color color;
  final bool onAccent;
  final String? photo;
  final double? height;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spoken = [
      homiziText(context, title),
      for (final line in lines) homiziText(context, line),
    ].join('. ');
    final plate = onAccent ? HomiziColors.white : HomiziColors.accentWash;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: plate,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: HomiziColors.ink),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(context, title),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Text(
            [for (final line in lines) homiziText(context, line)].join('\n'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: HomiziColors.inkSoft,
              height: 1.25,
            ),
          ),
        ),
        if (photo != null) ...[
          const SizedBox(height: 8),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ExcludeSemantics(
                child: Image.asset(
                  photo!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    final padded = Padding(
      padding: const EdgeInsets.all(12),
      child: trailing == null
          ? body
          : Row(
              children: [
                Expanded(child: body),
                const SizedBox(width: 8),
                trailing!,
              ],
            ),
    );

    return SizedBox(
      height: height,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: color,
        surfaceTintColor: HomiziColors.white,
        child: MergeSemantics(
          child: InkWell(
            key: cardKey,
            onTap: onTap,
            child: Semantics(
              label: spoken,
              child: ExcludeSemantics(child: padded),
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
    required this.keyName,
    required this.title,
    required this.line,
    required this.icon,
    required this.path,
  });

  final String keyName;
  final String title;
  final String line;
  final IconData icon;
  final String path;
}

final _services = <_ServiceItem>[
  const _ServiceItem(
    keyName: 'home-agreement',
    title: 'Rent agreement',
    line: 'Draft and send for e-sign',
    icon: Icons.draw_outlined,
    path: RoutePaths.agreements,
  ),
  _ServiceItem(
    keyName: 'home-packers',
    title: 'Packers and movers',
    line: 'A partner calls you back',
    icon: Icons.local_shipping_outlined,
    path: '${RoutePaths.serviceRequest}?kind=${ServiceKind.packersMovers.wire}',
  ),
  _ServiceItem(
    keyName: 'home-cleaning',
    title: 'Cleaning',
    line: 'A deep clean before move-in',
    icon: Icons.cleaning_services_outlined,
    path: '${RoutePaths.serviceRequest}?kind=${ServiceKind.cleaning.wire}',
  ),
  _ServiceItem(
    keyName: 'home-ac',
    title: 'AC repair',
    line: 'A partner calls you back',
    icon: Icons.ac_unit,
    path: '${RoutePaths.serviceRequest}?kind=${ServiceKind.acRepair.wire}',
  ),
  _ServiceItem(
    keyName: 'home-plumbing',
    title: 'Plumbing',
    line: 'A partner calls you back',
    icon: Icons.plumbing,
    path: '${RoutePaths.serviceRequest}?kind=${ServiceKind.plumbing.wire}',
  ),
  const _ServiceItem(
    keyName: 'home-help',
    title: 'Help and safety',
    line: 'Guides, safety, and contact',
    icon: Icons.gavel_outlined,
    path: RoutePaths.help,
  ),
];

/// Tints of the logo orange. No second brand hue.
abstract final class _Tone {
  static const clay = Color(0xFFFFD3C2);
  static const blush = Color(0xFFFFE4D6);
  static const mist = Color(0xFFFFF1EB);
}
