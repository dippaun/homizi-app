import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/home/home_matches.dart';
import 'package:homizi/features/roles/role_switch_bar.dart';
import 'package:homizi/features/saved/saved_heart_button.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/features/tenant/tenant_journey_section.dart';

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
              style: minTouchIconStyle(),
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
            style: minTouchIconStyle(),
            onPressed: () => context.go(RoutePaths.matches),
            icon: const Icon(Icons.chat_bubble_outline),
          ),
          const SavedHeartButton(),
          IconButton(
            key: const Key('home-profile'),
            tooltip: homiziText(context, 'Profile'),
            style: minTouchIconStyle(),
            onPressed: () => context.go(RoutePaths.profile),
            icon: ExcludeSemantics(
              child: HostAvatar(name: _avatarName(contact), radius: 16),
            ),
          ),
        ],
      ),
      body: const HomiziFrame(child: _HomeBody()),
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
        Text(
          homiziText(context, 'HOMIZI'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
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
    icon: Icons.event_outlined,
    label: 'Visits',
    path: RoutePaths.tenantVisits,
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
  _Jump(
    icon: Icons.person_outline,
    label: 'Profile',
    path: RoutePaths.profile,
    branch: true,
  ),
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
            label: Text(homiziText(context, jump.label)),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantHome = ref.watch(sessionProvider).homiziWire == 'tenant';
    return ListView(
      key: const Key('home-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const RoleSwitchBar(),
        if (tenantHome) ...const [
          TenantJourneySection(),
          SizedBox(height: _gap),
          _ServicesHeader(),
          SizedBox(height: _gap),
          _ServiceRow(),
          SizedBox(height: _gap),
          _PairRow(),
          SizedBox(height: _gap),
          _PayCard(),
        ] else ...const [
          _Hero(),
          SizedBox(height: _gap),
          _FeatureGrid(),
          SizedBox(height: _gap),
          _ServicesHeader(),
          SizedBox(height: _gap),
          _ServiceRow(),
          SizedBox(height: _gap),
          _PairRow(),
          SizedBox(height: _gap),
          _PayCard(),
          HomeMatches(),
        ],
      ],
    );
  }
}

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader();

  @override
  Widget build(BuildContext context) {
    return Text(
      homiziText(context, 'Home services'),
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8F5), _Tone.blush],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, 'Everything for your next home'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    homiziText(
                      context,
                      'Search, list, match, and settle a rental in India.',
                    ),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: HomiziColors.inkSoft,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(
              height: 64,
              child: CustomPaint(painter: _SkylinePainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  const _SkylinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final building = Paint()
      ..color = HomiziColors.accent.withValues(alpha: 0.22);
    final window = Paint()..color = const Color(0xFFFFF8F5);
    final widths = <double>[0.10, 0.08, 0.14, 0.07, 0.12, 0.09, 0.16, 0.08];
    final heights = <double>[0.46, 0.72, 0.58, 0.86, 0.50, 0.78, 0.64, 0.42];
    var x = size.width * 0.04;
    for (var i = 0; i < widths.length; i++) {
      final w = size.width * widths[i];
      final h = size.height * heights[i];
      final rect = Rect.fromLTWH(x, size.height - h, w, h);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        ),
        building,
      );
      final pane = w * 0.16;
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 2; col++) {
          final wx = rect.left + w * 0.22 + col * w * 0.34;
          final wy = rect.top + h * 0.18 + row * h * 0.22;
          if (wy + pane < size.height - 4) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(wx, wy, pane, pane),
                const Radius.circular(1),
              ),
              window,
            );
          }
        }
      }
      x += w + size.width * 0.012;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = _tileHeight(
          context,
          constraints.maxWidth < 360 ? 320 : 344,
        );
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
                    'Verified homes, zero brokerage',
                    'Flats, PGs & flatmates',
                  ],
                  color: HomiziColors.accent,
                  onTap: () => context.go(RoutePaths.explore),
                  art: const _CoverPhoto('assets/photos/exterior_01.webp'),
                ),
              ),
              const SizedBox(width: _gap),
              Expanded(
                flex: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _HubCard(
                        cardKey: const Key('home-list'),
                        title: 'List your home',
                        lines: const ['Verified tenants only'],
                        color: _Tone.clay,
                        onTap: () => context.push(RoutePaths.listingEditor),
                        art: const _CoverPhoto(
                          'assets/photos/exterior_02.webp',
                        ),
                      ),
                    ),
                    const SizedBox(height: _gap),
                    Expanded(
                      child: _HubCard(
                        cardKey: const Key('home-swipe'),
                        title: 'Swipe to match',
                        lines: const ['Right to like, left to pass'],
                        color: _Tone.blush,
                        onTap: () => context.go(RoutePaths.discover),
                        art: const _PortraitStack(),
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

  double _cardWidth(double viewport) {
    // A little more than two cards, so the next tile always peeks in.
    const visible = 2.35;
    final width = (viewport - _gap * (visible - 1)) / visible;
    return width.clamp(108.0, 168.0);
  }

  int _pageCount(double viewport) {
    final cardWidth = _cardWidth(viewport);
    final content =
        _services.length * cardWidth + (_services.length - 1) * _gap;
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
        final viewport = constraints.maxWidth;
        final cardWidth = _cardWidth(viewport);
        final pages = _pageCount(viewport);
        final page = pages <= 1 ? 0 : _page.clamp(0, pages - 1);
        return Column(
          children: [
            SizedBox(
              height: _tileHeight(context, 132),
              child: ListView.separated(
                key: const Key('home-services'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: _services.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: _gap),
                itemBuilder: (context, index) {
                  final item = _services[index];
                  return SizedBox(
                    width: cardWidth,
                    child: _HubCard(
                      cardKey: Key(item.keyName),
                      title: item.title,
                      lines: [item.line],
                      icon: item.icon,
                      color: index.isEven ? _Tone.mist : _Tone.blush,
                      compact: true,
                      onTap: () => context.push(item.path),
                    ),
                  );
                },
              ),
            ),
            if (pages > 1) ...[
              const SizedBox(height: _gap),
              Text(
                homiziText(context, 'Service page ${page + 1} of $pages'),
                key: const Key('home-service-page'),
              ),
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
              duration: motionDuration(
                context,
                const Duration(milliseconds: 180),
              ),
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
    return SizedBox(
      height: _tileHeight(context, 156),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _ToolsCard()),
          SizedBox(width: _gap),
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
      lines: const ['Split the rent', 'Track the deposit'],
      color: _Tone.blush,
      onTap: () => context.push(RoutePaths.tools),
      art: const _ChecklistArt(),
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
      lines: const ['A quick identity check', 'Only if you want'],
      color: _Tone.clay,
      onTap: () => context.push(RoutePaths.verifyIdentity),
      art: const _ShieldArt(),
    );
  }
}

class _PayCard extends StatelessWidget {
  const _PayCard();

  @override
  Widget build(BuildContext context) {
    return _HubCard(
      cardKey: const Key('home-pay'),
      title: 'Pay rent',
      lines: const ['Pay by UPI or card', 'Instant receipts'],
      color: HomiziColors.accent,
      height: _tileHeight(context, 132),
      beside: true,
      onTap: () => context.push(RoutePaths.payments),
      art: const _PayArt(),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.cardKey,
    required this.title,
    required this.lines,
    required this.color,
    required this.onTap,
    this.icon,
    this.art,
    this.compact = false,
    this.beside = false,
    this.height,
  });

  final Key cardKey;
  final String title;
  final List<String> lines;
  final IconData? icon;
  final Color color;
  final Widget? art;
  final bool compact;
  final bool beside;
  final double? height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spoken = [
      homiziText(context, title),
      for (final line in lines) homiziText(context, line),
    ].join('. ');
    final titleStyle =
        (compact ? theme.textTheme.titleSmall : theme.textTheme.titleMedium)
            ?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              height: 1.15,
            );
    final lineStyle = theme.textTheme.bodySmall?.copyWith(
      color: HomiziColors.inkSoft,
      height: 1.25,
      fontWeight: FontWeight.w500,
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HomiziColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: HomiziColors.ink),
          ),
          const SizedBox(height: 8),
        ],
        Text(homiziText(context, title), style: titleStyle),
        const SizedBox(height: 4),
        for (final line in lines)
          Text(homiziText(context, line), style: lineStyle),
      ],
    );

    final padded = Padding(
      padding: EdgeInsets.all(compact ? 12 : 14),
      child: art == null
          ? copy
          : beside
          ? Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 12),
                SizedBox(width: 96, height: 84, child: art),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                copy,
                SizedBox(height: compact ? 8 : 10),
                Expanded(child: art!),
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

class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        asset,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}

class _PortraitStack extends StatelessWidget {
  const _PortraitStack();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: 108,
        height: 44,
        child: Stack(
          children: [
            for (final (index, asset) in const [
              (0, 'assets/avatars/avatar_01.webp'),
              (1, 'assets/avatars/avatar_03.webp'),
              (2, 'assets/avatars/avatar_05.webp'),
            ])
              Positioned(left: index * 30, child: _Portrait(asset)),
          ],
        ),
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: HomiziColors.white,
        shape: BoxShape.circle,
      ),
      child: ClipOval(child: Image.asset(asset, fit: BoxFit.cover)),
    );
  }
}

class _ChecklistArt extends StatelessWidget {
  const _ChecklistArt();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _ChecklistPainter());
  }
}

class _ChecklistPainter extends CustomPainter {
  const _ChecklistPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paper = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 4, size.width * 0.72, size.height - 8),
      const Radius.circular(8),
    );
    canvas.drawRRect(paper, Paint()..color = HomiziColors.white);
    final ink = Paint()
      ..color = HomiziColors.ink
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = HomiziColors.accent;
    for (var i = 0; i < 3; i++) {
      final y = 16.0 + i * (size.height - 28) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(10, y, 8, 8),
          const Radius.circular(2),
        ),
        i == 0 ? fill : ink,
      );
      canvas.drawLine(Offset(24, y + 4), Offset(size.width * 0.58, y + 4), ink);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ShieldArt extends StatelessWidget {
  const _ShieldArt();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _ShieldPainter());
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.18, h * 0.12)
      ..lineTo(w * 0.62, h * 0.12)
      ..lineTo(w * 0.62, h * 0.48)
      ..quadraticBezierTo(w * 0.62, h * 0.86, w * 0.40, h * 0.96)
      ..quadraticBezierTo(w * 0.18, h * 0.86, w * 0.18, h * 0.48)
      ..close();
    canvas.drawPath(path, Paint()..color = HomiziColors.white);
    final check = Paint()
      ..color = HomiziColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.30, h * 0.48)
        ..lineTo(w * 0.38, h * 0.58)
        ..lineTo(w * 0.52, h * 0.36),
      check,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PayArt extends StatelessWidget {
  const _PayArt();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(painter: _PayPainter());
  }
}

class _PayPainter extends CustomPainter {
  const _PayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final card = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        0,
        size.height * 0.28,
        size.width * 0.78,
        size.height * 0.62,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(card, Paint()..color = HomiziColors.white);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(10, size.height * 0.40, 18, 12),
        const Radius.circular(2),
      ),
      Paint()..color = HomiziColors.accent,
    );
    final line = Paint()
      ..color = HomiziColors.inkSoft
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(10, size.height * 0.72),
      Offset(size.width * 0.42, size.height * 0.72),
      line,
    );
    final phone = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.48,
        2,
        size.width * 0.42,
        size.height * 0.78,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(phone, Paint()..color = HomiziColors.ink);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.69, size.height * 0.40),
          width: size.width * 0.22,
          height: size.width * 0.22,
        ),
        const Radius.circular(20),
      ),
      Paint()..color = HomiziColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    line: 'E-sign ready',
    icon: Icons.draw_outlined,
    path: RoutePaths.agreements,
  ),
  _ServiceItem(
    keyName: 'home-packers',
    title: 'Packers & movers',
    line: 'City shifts',
    icon: Icons.local_shipping_outlined,
    path: '${RoutePaths.serviceRequest}?kind=${ServiceKind.packersMovers.wire}',
  ),
  _ServiceItem(
    keyName: 'home-cleaning',
    title: 'Cleaning',
    line: 'Move-in clean',
    icon: Icons.cleaning_services_outlined,
    path: '${RoutePaths.serviceRequest}?kind=${ServiceKind.cleaning.wire}',
  ),
  _ServiceItem(
    keyName: 'home-ac',
    title: 'AC repair',
    line: 'Stay cool',
    icon: Icons.ac_unit,
    path: '${RoutePaths.serviceRequest}?kind=${ServiceKind.acRepair.wire}',
  ),
  _ServiceItem(
    keyName: 'home-plumbing',
    title: 'Plumbing',
    line: 'Stop a leak',
    icon: Icons.plumbing,
    path: '${RoutePaths.serviceRequest}?kind=${ServiceKind.plumbing.wire}',
  ),
  const _ServiceItem(
    keyName: 'home-legal',
    title: 'Legal help',
    line: 'Plain answers',
    icon: Icons.gavel_outlined,
    path: RoutePaths.help,
  ),
];

const _gap = 16.0;

/// Keeps the default tile size, and grows it when system text is larger.
double _tileHeight(BuildContext context, double base) {
  final factor = MediaQuery.textScalerOf(context).scale(1);
  if (factor <= 1) {
    return base;
  }
  return base * factor + 120;
}

/// Tints of the logo orange. No second brand hue.
abstract final class _Tone {
  static const clay = Color(0xFFFFD3C2);
  static const blush = Color(0xFFFFE4D6);
  static const mist = Color(0xFFFFF1EB);
}
