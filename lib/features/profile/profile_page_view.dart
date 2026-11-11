import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/profile/domain/profile_completion.dart';
import 'package:homizi/features/profile/profile_page_model.dart';
import 'package:homizi/features/profile_create/public_profile.dart';

const _fontFallback = <String>['Noto Sans', 'Roboto'];

class ProfilePageView extends StatelessWidget {
  const ProfilePageView({
    required this.model,
    required this.onOpen,
    required this.onShare,
    required this.onHostPreview,
    this.showSpecNav = false,
    this.onRefresh,
    this.avatar,
    this.notice,
    super.key,
  });

  final ProfilePageModel model;
  final void Function(String route, {bool go}) onOpen;
  final VoidCallback onShare;
  final VoidCallback onHostPreview;
  final bool showSpecNav;
  final Future<void> Function()? onRefresh;
  final Widget? avatar;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final header = model.darkHeader
        ? HomiziColors.ink
        : HomiziColors.brandDeepOrange;
    return Scaffold(
      backgroundColor: HomiziColors.soft,
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: onRefresh ?? () async {},
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 220,
                        child: _HeaderBackdrop(
                          color: header,
                          dark: model.darkHeader,
                          onShare: onShare,
                        ),
                      ),
                      Column(
                        children: [
                          const SizedBox(height: 176),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _IdentityCard(model: model, onOpen: onOpen),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 118,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: avatar ?? _InitialsAvatar(model: model),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: Column(
                      children: [
                        if (notice != null) ...[
                          _Notice(message: notice!),
                          const SizedBox(height: 12),
                        ],
                        _StatsCard(model: model, onOpen: onOpen),
                        const SizedBox(height: 12),
                        for (final block in model.blocks) ...[
                          _BlockCard(block: block, onOpen: onOpen),
                          const SizedBox(height: 12),
                        ],
                        _ActionButton(
                          action: model.primary,
                          filled: true,
                          onOpen: onOpen,
                          onShare: onShare,
                          onHostPreview: onHostPreview,
                        ),
                        const SizedBox(height: 10),
                        _ActionButton(
                          action: model.secondary,
                          filled: false,
                          onOpen: onOpen,
                          onShare: onShare,
                          onHostPreview: onHostPreview,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showSpecNav) _SpecNav(onOpen: onOpen),
        ],
      ),
    );
  }
}

class _HeaderBackdrop extends StatelessWidget {
  const _HeaderBackdrop({
    required this.color,
    required this.dark,
    required this.onShare,
  });

  final Color color;
  final bool dark;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RingPainter(dark: dark)),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _RoundIconButton(
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onPressed: () => HomiziBackButton.leave(context),
                      ),
                    ),
                    const _Wordmark(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _RoundIconButton(
                        icon: Icons.ios_share,
                        tooltip: 'Share',
                        buttonKey: const Key('profile-share'),
                        onPressed: onShare,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const HomiziSquareMark(size: 22, color: HomiziColors.white),
        const SizedBox(width: 8),
        Text(
          'HOMIZI',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontFamily: 'PlusJakartaSans',
            fontFamilyFallback: _fontFallback,
            color: HomiziColors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.buttonKey,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: buttonKey,
      tooltip: homiziText(context, tooltip),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        minimumSize: const Size(40, 40),
        fixedSize: const Size(40, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.72);
    if (dark) {
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = HomiziColors.brandDeepOrange;
      final warm = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = HomiziColors.brandOrange;
      for (var index = 0; index < 7; index++) {
        _dashedCircle(
          canvas,
          center,
          58 + index * 26,
          index.isEven ? dash : warm,
        );
      }
      return;
    }
    for (var index = 0; index < 8; index++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = index.isEven ? 16 : 9
        ..color = HomiziColors.white.withValues(
          alpha: index.isEven ? 0.14 : 0.28,
        );
      canvas.drawCircle(center, 50 + index * 24, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.dark != dark;
}

void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint) {
  const steps = 42;
  const sweep = (math.pi * 2) / steps;
  final rect = Rect.fromCircle(center: center, radius: radius);
  for (var index = 0; index < steps; index++) {
    canvas.drawArc(rect, index * sweep, sweep * 0.55, false, paint);
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.model});

  final ProfilePageModel model;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: HomiziColors.white,
              border: Border.all(color: HomiziColors.white, width: 4),
              boxShadow: const [
                BoxShadow(
                  color: HomiziColors.shadow,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: SizedBox(
              width: 108,
              height: 108,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HomiziColors.white,
                  border: Border.all(
                    color: model.darkHeader
                        ? HomiziColors.brandDeepOrange
                        : HomiziColors.white,
                    width: 3,
                  ),
                ),
                child: Center(
                  child: Text(
                    model.initials,
                    key: const Key('profile-initials'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'PlusJakartaSans',
                      fontFamilyFallback: _fontFallback,
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (model.verified)
            const Positioned(right: 2, bottom: 2, child: _VerifiedTick()),
        ],
      ),
    );
  }
}

class _VerifiedTick extends StatelessWidget {
  const _VerifiedTick();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.success,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: HomiziColors.white, width: 2),
        ),
      ),
      child: SizedBox(
        width: 26,
        height: 26,
        child: Icon(Icons.check, size: 16, color: HomiziColors.onSuccess),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.model, required this.onOpen});

  final ProfilePageModel model;
  final void Function(String route, {bool go}) onOpen;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 62, 18, 18),
        child: Column(
          children: [
            Text(
              homiziText(context, model.name),
              key: const Key('profile-name'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: 'PlusJakartaSans',
                fontFamilyFallback: _fontFallback,
                fontWeight: FontWeight.w800,
                color: HomiziColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              homiziText(context, model.handleLine),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                fontFamilyFallback: _fontFallback,
                color: HomiziColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                InkWell(
                  key: const Key('profile-change-role'),
                  onTap: () => onOpen(RoutePaths.role),
                  borderRadius: BorderRadius.circular(20),
                  child: _RoleChip(icon: model.roleIcon, label: model.roleChip),
                ),
                if (model.verified) const _VerifiedPill(),
              ],
            ),
            const SizedBox(height: 12),
            _PlaceLine(model: model),
            const SizedBox(height: 12),
            Text(
              homiziText(context, model.bio),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                fontFamilyFallback: _fontFallback,
                color: HomiziColors.inkSoft,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('profile-role'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HomiziColors.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: HomiziColors.brandRedOrange),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              homiziText(context, label),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFamily: 'PlusJakartaSans',
                fontFamilyFallback: _fontFallback,
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HomiziColors.successWash,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 15, color: HomiziColors.success),
          const SizedBox(width: 4),
          Text(
            homiziText(context, 'Verified'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontFamily: 'PlusJakartaSans',
              fontFamilyFallback: _fontFallback,
              color: HomiziColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceLine extends StatelessWidget {
  const _PlaceLine({required this.model});

  final ProfilePageModel model;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontFamily: 'Inter',
      fontFamilyFallback: _fontFallback,
      color: HomiziColors.muted,
      height: 1.3,
    );
    const pin = Icon(
      Icons.location_on_outlined,
      size: 16,
      color: HomiziColors.muted,
    );
    if (!model.splitPlace) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          pin,
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              homiziText(context, '${model.placeLeft} · ${model.placeRight}'),
              textAlign: TextAlign.center,
              style: style,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              pin,
              const SizedBox(width: 4),
              Flexible(
                child: Text(homiziText(context, model.placeLeft), style: style),
              ),
            ],
          ),
        ),
        Text('·', style: style),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            homiziText(context, model.placeRight),
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.model, required this.onOpen});

  final ProfilePageModel model;
  final void Function(String route, {bool go}) onOpen;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            for (final stat in model.stats)
              Expanded(
                child: InkWell(
                  onTap: () => onOpen(stat.route, go: stat.go),
                  child: Column(
                    children: [
                      Text(
                        stat.value,
                        key: stat.valueKey,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontFamily: 'PlusJakartaSans',
                              fontFamilyFallback: _fontFallback,
                              fontWeight: FontWeight.w800,
                              color: HomiziColors.ink,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        homiziText(context, stat.label),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'Inter',
                          fontFamilyFallback: _fontFallback,
                          color: HomiziColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.block, required this.onOpen});

  final ProfileBlock block;
  final void Function(String route, {bool go}) onOpen;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    homiziText(context, block.title),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontFamily: 'PlusJakartaSans',
                      fontFamilyFallback: _fontFallback,
                      fontWeight: FontWeight.w800,
                      color: HomiziColors.ink,
                    ),
                  ),
                ),
                if (block.actionLabel != null && block.actionRoute != null)
                  _TextLink(
                    label: block.actionLabel!,
                    linkKey: block.actionKey,
                    onTap: () => onOpen(block.actionRoute!, go: block.actionGo),
                  ),
              ],
            ),
            if (block.priorities.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var index = 0; index < block.priorities.length; index++)
                _PriorityRow(index: index + 1, item: block.priorities[index]),
            ],
            if (block.listings.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final listing in block.listings)
                _ListingRow(listing: listing, onOpen: onOpen),
            ],
            if (block.chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in block.chips)
                    _SoftChip(
                      label: chip.label,
                      onTap: () => onOpen(chip.route, go: chip.go),
                    ),
                ],
              ),
            ],
            if (block.people.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final person in block.people) _PersonRow(person: person),
            ],
            if (block.facts.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final fact in block.facts) _FactRow(fact: fact),
            ],
            if (block.checks.isNotEmpty) ...[
              const SizedBox(height: 4),
              for (final check in block.checks)
                _CheckRow(check: check, onOpen: onOpen),
            ],
            if (block.footnote != null) ...[
              const SizedBox(height: 8),
              Text(
                homiziText(context, block.footnote!),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'Inter',
                  fontFamilyFallback: _fontFallback,
                  color: HomiziColors.muted,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriorityRow extends StatelessWidget {
  const _PriorityRow({required this.index, required this.item});

  final int index;
  final ProfilePriority item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              color: HomiziColors.brandRedOrange,
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 26,
              height: 26,
              child: Center(
                child: Text(
                  '$index',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontFamily: 'PlusJakartaSans',
                    fontFamilyFallback: _fontFallback,
                    color: HomiziColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, item.title),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'PlusJakartaSans',
                    fontFamilyFallback: _fontFallback,
                    fontWeight: FontWeight.w700,
                    color: HomiziColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  homiziText(context, item.detail),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'Inter',
                    fontFamilyFallback: _fontFallback,
                    color: HomiziColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing, required this.onOpen});

  final ProfileListing listing;
  final void Function(String route, {bool go}) onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpen(listing.route, go: listing.go),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: HomiziColors.accentWash,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.home_outlined,
                  color: HomiziColors.brandRedOrange,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, listing.title),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: 'PlusJakartaSans',
                      fontFamilyFallback: _fontFallback,
                      fontWeight: FontWeight.w800,
                      color: HomiziColors.ink,
                    ),
                  ),
                  Text(
                    homiziText(context, listing.place),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'Inter',
                      fontFamilyFallback: _fontFallback,
                      color: HomiziColors.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    homiziText(context, listing.price),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: 'PlusJakartaSans',
                      fontFamilyFallback: _fontFallback,
                      fontWeight: FontWeight.w800,
                      color: HomiziColors.ink,
                    ),
                  ),
                  Text(
                    homiziText(context, listing.meta),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'Inter',
                      fontFamilyFallback: _fontFallback,
                      color: HomiziColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (listing.matchLabel != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  homiziText(context, listing.matchLabel!),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontFamily: 'PlusJakartaSans',
                    fontFamilyFallback: _fontFallback,
                    color: HomiziColors.success,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            else if (listing.status != null)
              _StatusPill(label: listing.status!, tone: listing.tone),
          ],
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person});

  final ProfilePerson person;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: person.open ? HomiziColors.soft : HomiziColors.accentWash,
              shape: BoxShape.circle,
              border: person.open ? Border.all(color: HomiziColors.line) : null,
            ),
            child: SizedBox(
              width: 42,
              height: 42,
              child: Center(
                child: Text(
                  person.initials,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontFamily: 'PlusJakartaSans',
                    fontFamilyFallback: _fontFallback,
                    fontWeight: FontWeight.w800,
                    color: person.open
                        ? HomiziColors.muted
                        : HomiziColors.brandRedOrange,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, person.name),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: 'PlusJakartaSans',
                    fontFamilyFallback: _fontFallback,
                    fontWeight: FontWeight.w800,
                    color: HomiziColors.ink,
                  ),
                ),
                Text(
                  homiziText(context, person.detail),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'Inter',
                    fontFamilyFallback: _fontFallback,
                    color: HomiziColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.fact});

  final ProfileFact fact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(fact.icon, size: 20, color: HomiziColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              homiziText(context, fact.label),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'Inter',
                fontFamilyFallback: _fontFallback,
                color: HomiziColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              homiziText(context, fact.value),
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFamily: 'PlusJakartaSans',
                fontFamilyFallback: _fontFallback,
                fontWeight: FontWeight.w700,
                color: HomiziColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.onOpen});

  final ProfileCheck check;
  final void Function(String route, {bool go}) onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onOpen(check.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(check.icon, size: 22, color: HomiziColors.inkSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, check.title),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontFamily: 'PlusJakartaSans',
                      fontFamilyFallback: _fontFallback,
                      fontWeight: FontWeight.w700,
                      color: HomiziColors.ink,
                    ),
                  ),
                  Text(
                    homiziText(context, check.detail),
                    key: check.detailKey,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'Inter',
                      fontFamilyFallback: _fontFallback,
                      color: HomiziColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusPill(
              label: check.status,
              tone: check.tone,
              pillKey: check.statusKey,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone, this.pillKey});

  final String label;
  final ProfilePillTone tone;
  final Key? pillKey;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      ProfilePillTone.good => (HomiziColors.successWash, HomiziColors.success),
      ProfilePillTone.pending => (
        HomiziColors.warningWash,
        HomiziColors.warning,
      ),
      ProfilePillTone.neutral => (HomiziColors.soft, HomiziColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tone == ProfilePillTone.good) ...[
            Icon(Icons.check, size: 14, color: foreground),
            const SizedBox(width: 2),
          ],
          Text(
            homiziText(context, label),
            key: pillKey,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontFamily: 'PlusJakartaSans',
              fontFamilyFallback: _fontFallback,
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  const _SoftChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.soft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            homiziText(context, label),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontFamily: 'Inter',
              fontFamilyFallback: _fontFallback,
              color: HomiziColors.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  const _TextLink({required this.label, required this.onTap, this.linkKey});

  final String label;
  final VoidCallback onTap;
  final Key? linkKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: linkKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          homiziText(context, label),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontFamily: 'PlusJakartaSans',
            fontFamilyFallback: _fontFallback,
            color: HomiziColors.brandRedOrange,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.filled,
    required this.onOpen,
    required this.onShare,
    required this.onHostPreview,
  });

  final ProfileAction action;
  final bool filled;
  final void Function(String route, {bool go}) onOpen;
  final VoidCallback onShare;
  final VoidCallback onHostPreview;

  @override
  Widget build(BuildContext context) {
    void press() {
      switch (action.kind) {
        case ProfileActionKind.share:
          onShare();
          break;
        case ProfileActionKind.preview:
          onHostPreview();
          break;
        case ProfileActionKind.go:
          onOpen(action.route, go: true);
          break;
        case ProfileActionKind.push:
          onOpen(action.route);
          break;
      }
    }

    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(action.icon, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            homiziText(context, action.label),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
    if (filled) {
      return FilledButton(
        key: action.buttonKey,
        onPressed: press,
        child: child,
      );
    }
    return OutlinedButton(
      key: action.buttonKey,
      onPressed: press,
      child: child,
    );
  }
}

class _SpecNav extends StatelessWidget {
  const _SpecNav({required this.onOpen});

  final void Function(String route, {bool go}) onOpen;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, 'Home', RoutePaths.home),
      (Icons.search, 'Search', RoutePaths.explore),
      (Icons.handshake_outlined, 'Matches', RoutePaths.matches),
      (Icons.chat_bubble_outline, 'Chat', RoutePaths.chats),
      (Icons.person, 'Profile', RoutePaths.profile),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: HomiziColors.white,
        border: Border(top: BorderSide(color: HomiziColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: InkWell(
                    onTap: index == items.length - 1
                        ? null
                        : () => onOpen(items[index].$3, go: true),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          items[index].$1,
                          size: 22,
                          color: index == items.length - 1
                              ? HomiziColors.brandRedOrange
                              : HomiziColors.muted,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          homiziText(context, items[index].$2),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                fontFamily: 'PlusJakartaSans',
                                fontFamilyFallback: _fontFallback,
                                fontWeight: FontWeight.w700,
                                color: index == items.length - 1
                                    ? HomiziColors.brandRedOrange
                                    : HomiziColors.muted,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: HomiziColors.shadowSoft,
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      homiziText(context, message),
      key: const Key('profile-error'),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: HomiziColors.error,
        fontFamily: 'Inter',
        fontFamilyFallback: _fontFallback,
      ),
    );
  }
}

class ProfileHostPreviewPage extends StatelessWidget {
  const ProfileHostPreviewPage({required this.profile, super.key});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.soft,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'As hosts see you')),
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profileInitials(profile.publicName),
                    key: const Key('profile-initials-preview'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontFamily: 'PlusJakartaSans',
                      fontFamilyFallback: _fontFallback,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    homiziText(context, profile.publicName),
                    key: const Key('public-profile-name'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    homiziText(
                      context,
                      'Hosts see your name and the checks that have passed. Your phone number stays hidden.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: HomiziColors.muted,
                      fontFamily: 'Inter',
                      fontFamilyFallback: _fontFallback,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
