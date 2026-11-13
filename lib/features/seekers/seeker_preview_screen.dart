import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/homizi_home_bar.dart';
import 'package:homizi/features/chat/chat_screen.dart';
import 'package:homizi/features/chat/thread_providers.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';
import 'package:homizi/features/seekers/seeker_confirm_screen.dart';
import 'package:homizi/features/seekers/seeker_score.dart';
import 'package:homizi/features/seekers/seeker_shortlist.dart';

class SeekerPreviewArgs {
  const SeekerPreviewArgs({
    required this.profile,
    required this.property,
    required this.fit,
  });

  final SeekerPublicProfile profile;
  final HostProperty property;
  final SeekerFit fit;
}

class SeekerPreviewScreen extends ConsumerStatefulWidget {
  const SeekerPreviewScreen({
    required this.requirementId,
    this.args,
    super.key,
  });

  final String requirementId;
  final SeekerPreviewArgs? args;

  @override
  ConsumerState<SeekerPreviewScreen> createState() =>
      _SeekerPreviewScreenState();
}

class _SeekerPreviewScreenState extends ConsumerState<SeekerPreviewScreen> {
  var _tab = 0;

  SeekerPreviewArgs? get _args => widget.args;

  @override
  Widget build(BuildContext context) {
    final args = _args;
    if (args == null || args.profile.id != widget.requirementId) {
      return const _MissingSeeker();
    }
    final deck = ref.watch(seekerDeckProvider);
    final saved = deck.shortlisted.contains(args.profile.id);
    return Scaffold(
      key: const Key('seeker-preview'),
      backgroundColor: HomiziColors.soft,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        elevation: 0,
        leading: const HomiziBackButton(),
        title: const HomiziLockup(),
        actions: [
          IconButton(
            key: const Key('seeker-preview-bell'),
            tooltip: homiziText(context, 'Notifications'),
            onPressed: () => _open(context, RoutePaths.notifications),
            icon: const Icon(Icons.notifications_none, color: HomiziColors.ink),
          ),
          IconButton(
            key: const Key('seeker-preview-heart'),
            tooltip: homiziText(context, 'Shortlist'),
            onPressed: () => ref
                .read(seekerDeckProvider.notifier)
                .toggleShortlist(args.profile.id),
            icon: Icon(
              saved ? Icons.favorite : Icons.favorite_border,
              color: saved ? HomiziColors.logoOrange : HomiziColors.ink,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  children: [
                    _Header(args: args),
                    const SizedBox(height: 12),
                    _Tabs(
                      index: _tab,
                      onChanged: (value) => setState(() => _tab = value),
                    ),
                    const SizedBox(height: 12),
                    switch (_tab) {
                      0 => _RequirementBody(args: args),
                      1 => _AboutBody(profile: args.profile),
                      2 => _CompatibilityBody(args: args),
                      _ => _ChatBody(
                        profile: args.profile,
                        onOpen: () => _message(args),
                      ),
                    },
                  ],
                ),
              ),
            ),
          ),
          _Actions(
            onNotFit: () => _notFit(args),
            onLater: () => _later(args),
            onMessage: () => _message(args),
          ),
        ],
      ),
    );
  }

  Future<void> _notFit(SeekerPreviewArgs args) async {
    ref.read(seekerDeckProvider.notifier).dismiss(args.profile.id);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => SeekerConfirmScreen(
          title: 'Not a fit',
          message:
              '${args.profile.name} is hidden for ${args.property.label}. Phone, email, and verification documents were not used.',
          actionLabel: 'Back to seekers',
          onAction: () {
            final navigator = Navigator.of(routeContext);
            navigator.pop();
            if (navigator.canPop()) {
              navigator.pop();
            }
          },
        ),
      ),
    );
  }

  Future<void> _later(SeekerPreviewArgs args) async {
    ref.read(seekerDeckProvider.notifier).markLater(args.profile.id);
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SeekerConfirmScreen(
          title: 'Saved for later',
          message:
              '${args.profile.name} stays on this list for ${args.property.label}. You can open the profile again from Interested Seekers.',
          actionLabel: 'Back to profile',
          onAction: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<void> _message(SeekerPreviewArgs args) async {
    final matchId = 'seeker-${args.profile.id}';
    var opened = false;
    try {
      await ref.read(threadGatewayProvider).load(matchId);
      opened = true;
    } catch (_) {
      opened = false;
    }
    ref.read(seekerDeckProvider.notifier).connect(args.profile.id);
    if (!mounted) {
      return;
    }
    final name = args.profile.name;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) => SeekerConfirmScreen(
          title: opened ? 'Chat is ready' : 'Connect request saved',
          message: opened
              ? 'Messages with $name stay in Homizi. Phone numbers, email addresses, and verification documents stay hidden until you both choose to share them.'
              : '$name has not connected yet. The request is saved on this device. Chat stays closed until you both connect. No phone number or document is shared.',
          actionLabel: opened ? 'Open chat' : 'Back to profile',
          onAction: () {
            if (!opened) {
              Navigator.of(routeContext).pop();
              return;
            }
            _openChat(routeContext, args, matchId);
          },
        ),
      ),
    );
  }
}

void _openChat(BuildContext context, SeekerPreviewArgs args, String matchId) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.push(
      RoutePaths.chat(
        matchId,
        name: args.profile.name,
        title: args.property.label,
        avatar: args.profile.photoAsset,
      ),
    );
    return;
  }
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => ChatScreen(
        matchId: matchId,
        otherName: args.profile.name,
        listingTitle: args.property.label,
        avatarUrl: args.profile.photoAsset.isEmpty
            ? null
            : args.profile.photoAsset,
      ),
    ),
  );
}

void _open(BuildContext context, String path) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.push(path);
  }
}

class _MissingSeeker extends StatelessWidget {
  const _MissingSeeker();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Seeker')),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            homiziText(context, 'Open this seeker from Interested Seekers.'),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.args});

  final SeekerPreviewArgs args;

  @override
  Widget build(BuildContext context) {
    final profile = args.profile;
    final theme = Theme.of(context);
    final place = [
      if (profile.localities.isNotEmpty) profile.localities.first,
      profile.city,
    ].join(', ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'seeker-photo-${profile.id}',
                      child: _Face(profile: profile, size: 64),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  homiziText(context, profile.name),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: HomiziColors.ink,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (profile.verified) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: HomiziColors.success,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          _Chip(label: profile.kindLabel),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  homiziText(
                    context,
                    [
                      if (profile.age != null) '${profile.age}',
                      profile.occupationLabel,
                    ].join(' · '),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: HomiziColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: HomiziColors.logoOrange,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        homiziText(context, place),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: HomiziColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (profile.verified) ...[
                  const SizedBox(height: 6),
                  const Row(
                    children: [
                      Icon(
                        Icons.verified,
                        size: 16,
                        color: HomiziColors.success,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Verified Seeker',
                        style: TextStyle(
                          color: HomiziColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _MatchRing(percent: args.fit.percent, reasons: args.fit.topReasons),
        ],
      ),
    );
  }
}

class _MatchRing extends StatelessWidget {
  const _MatchRing({required this.percent, required this.reasons});

  final int percent;
  final List<String> reasons;

  @override
  Widget build(BuildContext context) {
    final shown = reasons.take(4).toList();
    return SizedBox(
      width: 132,
      child: Column(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: CustomPaint(
              painter: _RingPainter(percent / 100),
              child: Center(
                child: Text(
                  '$percent%',
                  key: const Key('seeker-preview-percent'),
                  style: const TextStyle(
                    color: HomiziColors.success,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            homiziText(context, 'Match for Your Property'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HomiziColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          for (final reason in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 12,
                    color: HomiziColors.success,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      homiziText(context, reason),
                      style: const TextStyle(
                        color: HomiziColors.inkSoft,
                        fontSize: 10,
                      ),
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

class _RingPainter extends CustomPainter {
  const _RingPainter(this.fraction);

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    final track = Paint()
      ..color = HomiziColors.successWash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    final arc = Paint()
      ..color = HomiziColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * fraction.clamp(0, 1),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.fraction != fraction;
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Requirement Details',
      'About Seeker',
      'Compatibility',
      'Chat',
    ];
    const keys = [
      'seeker-tab-requirements',
      'seeker-tab-about',
      'seeker-tab-compatibility',
      'seeker-tab-chat',
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomiziColors.line),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  key: Key(keys[i]),
                  label: Text(homiziText(context, labels[i])),
                  selected: index == i,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: index == i ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                  selectedColor: HomiziColors.accentWash,
                  backgroundColor: HomiziColors.white,
                  side: BorderSide(
                    color: index == i ? HomiziColors.accent : HomiziColors.line,
                  ),
                  onSelected: (_) => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequirementBody extends StatelessWidget {
  const _RequirementBody({required this.args});

  final SeekerPreviewArgs args;

  @override
  Widget build(BuildContext context) {
    final profile = args.profile;
    final budget =
        '${formatInr(profile.budgetMinInr)} – ${formatInr(profile.budgetMaxInr)}';
    final budgetLine = profile.perPerson ? '$budget / person' : budget;
    final where = profile.localities.isEmpty
        ? profile.city
        : profile.localities.join(', ');
    return Column(
      children: [
        _Section(
          icon: Icons.home_outlined,
          title: 'Seeker Requirement',
          subtitle:
              "Here's what ${profile.name.split(' ').first} is looking for",
          child: Column(
            children: [
              _Fact(
                icon: Icons.apartment,
                label: 'Property Type',
                value: profile.propertyLine,
              ),
              _Fact(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Budget',
                value: budgetLine,
              ),
              _Fact(
                icon: Icons.place_outlined,
                label: 'Preferred Location',
                value: where,
              ),
              _Fact(
                icon: Icons.calendar_today_outlined,
                label: 'Move-in Date',
                value: profile.moveInLabel.isEmpty
                    ? 'Flexible'
                    : profile.moveInLabel,
              ),
              _Fact(
                icon: Icons.group_outlined,
                label: 'Looking With',
                value: profile.lookingWith.isEmpty
                    ? profile.kindLabel
                    : profile.lookingWith,
              ),
              _Fact(
                icon: Icons.timelapse,
                label: 'Stay Duration',
                value: profile.stayLabel.isEmpty
                    ? 'Not shared'
                    : profile.stayLabel,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.spa_outlined,
          title: 'Lifestyle & Living Preferences',
          child: profile.lifestyle.isEmpty
              ? const _Muted('Lifestyle was not shared.')
              : _ChipWrap(labels: profile.lifestyle),
        ),
        const SizedBox(height: 12),
        _Section(
          icon: Icons.gavel_outlined,
          title: 'House Rules Preference',
          child: profile.houseRules.isEmpty
              ? const _Muted('House rules were not shared.')
              : _ChipWrap(labels: profile.houseRules),
        ),
        const SizedBox(height: 12),
        _Why(args: args),
        const SizedBox(height: 12),
        _Info(profile: profile),
        const SizedBox(height: 12),
        _AboutCard(profile: profile),
      ],
    );
  }
}

class _AboutBody extends StatelessWidget {
  const _AboutBody({required this.profile});

  final SeekerPublicProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Info(profile: profile),
        const SizedBox(height: 12),
        _AboutCard(profile: profile),
      ],
    );
  }
}

class _CompatibilityBody extends StatelessWidget {
  const _CompatibilityBody({required this.args});

  final SeekerPreviewArgs args;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.pie_chart_outline,
      title: 'Compatibility',
      subtitle:
          '${args.fit.percent}% is this seeker against your saved host priorities, or against this home when you have not saved a list. A must-have that misses is left off Interested Seekers.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final reason in args.fit.topReasons)
            _Line(
              icon: Icons.check_circle,
              color: HomiziColors.success,
              text: reason,
            ),
          for (final gap in args.fit.missing)
            _Line(
              icon: Icons.info_outline,
              color: HomiziColors.muted,
              text: gap,
            ),
        ],
      ),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody({required this.profile, required this.onOpen});

  final SeekerPublicProfile profile;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.chat_bubble_outline,
      title: 'Chat',
      subtitle:
          'Messages stay in Homizi. Phone numbers, email addresses, and verification documents stay hidden until you both choose to share them.',
      child: FilledButton(
        key: const Key('seeker-chat-open'),
        style: FilledButton.styleFrom(
          backgroundColor: HomiziColors.accent,
          foregroundColor: HomiziColors.ink,
        ),
        onPressed: onOpen,
        child: Text(homiziText(context, 'Message & Connect')),
      ),
    );
  }
}

class _Why extends StatelessWidget {
  const _Why({required this.args});

  final SeekerPreviewArgs args;

  @override
  Widget build(BuildContext context) {
    final reasons = args.fit.topReasons.take(3).join(', ');
    final sentence = reasons.isEmpty
        ? '${args.profile.name} is discoverable for ${args.property.label}.'
        : 'Matches your ${args.property.label}: $reasons.';
    return _Section(
      icon: Icons.home_work_outlined,
      title: "Why It's a Good Fit for Your Property",
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              args.property.photoAsset,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 72,
                height: 72,
                color: HomiziColors.soft,
                child: const Icon(
                  Icons.home_outlined,
                  color: HomiziColors.muted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: HomiziColors.success,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    homiziText(context, sentence),
                    style: const TextStyle(
                      color: HomiziColors.inkSoft,
                      height: 1.35,
                    ),
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

class _Info extends StatelessWidget {
  const _Info({required this.profile});

  final SeekerPublicProfile profile;

  @override
  Widget build(BuildContext context) {
    return _Section(
      icon: Icons.badge_outlined,
      title: 'Seeker Info',
      child: Column(
        children: [
          _Fact(
            icon: Icons.school_outlined,
            label: 'Education',
            value: profile.education.isEmpty ? 'Not shared' : profile.education,
          ),
          _Fact(
            icon: Icons.location_city_outlined,
            label: 'Hometown',
            value: profile.hometown.isEmpty ? 'Not shared' : profile.hometown,
          ),
          _Fact(
            icon: Icons.translate,
            label: 'Languages',
            value: profile.languages.isEmpty
                ? 'Not shared'
                : profile.languages.join(', '),
          ),
          const _Fact(
            icon: Icons.circle,
            label: 'Active on Homizi',
            value: 'Discoverable brief',
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.profile});

  final SeekerPublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final first = profile.name.split(' ').first;
    final body = profile.about.trim().isEmpty
        ? 'No public note yet.'
        : '"${profile.about.trim()}"';
    return _Section(
      icon: Icons.format_quote,
      title: 'About $first',
      child: Text(
        homiziText(context, body),
        style: const TextStyle(color: HomiziColors.inkSoft, height: 1.4),
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.onNotFit,
    required this.onLater,
    required this.onMessage,
  });

  final VoidCallback onNotFit;
  final VoidCallback onLater;
  final VoidCallback onMessage;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('seeker-not-fit'),
                  onPressed: onNotFit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomiziColors.ink,
                    side: const BorderSide(color: HomiziColors.line),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: Text(
                    homiziText(context, 'Not a Fit'),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: HomiziColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('seeker-maybe-later'),
                  onPressed: onLater,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: HomiziColors.ink,
                    side: const BorderSide(color: HomiziColors.line),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.star_border, size: 16),
                  label: Text(
                    homiziText(context, 'Maybe Later'),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: HomiziColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  key: const Key('seeker-message'),
                  style: FilledButton.styleFrom(
                    backgroundColor: HomiziColors.accent,
                    foregroundColor: HomiziColors.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                  onPressed: onMessage,
                  child: Text(
                    homiziText(context, 'Message & Connect'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: HomiziColors.ink,
                    ),
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

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: HomiziColors.logoOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  homiziText(context, title),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              homiziText(context, subtitle!),
              style: const TextStyle(color: HomiziColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: HomiziColors.logoOrange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, label),
                  style: const TextStyle(
                    color: HomiziColors.muted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  homiziText(context, value),
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontWeight: FontWeight.w700,
                    color: HomiziColors.ink,
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

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: HomiziColors.successWash,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              homiziText(context, label),
              style: const TextStyle(
                color: HomiziColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        homiziText(context, label),
        style: const TextStyle(
          color: HomiziColors.ink,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              homiziText(context, text),
              style: const TextStyle(color: HomiziColors.inkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      homiziText(context, text),
      style: const TextStyle(color: HomiziColors.muted),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.profile, required this.size});

  final SeekerPublicProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = profile.photoAsset;
    final initials = _initials(profile.name);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: HomiziColors.accentWash,
      backgroundImage: asset.isEmpty ? null : AssetImage(asset),
      child: asset.isEmpty
          ? Text(
              initials,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: HomiziColors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: HomiziColors.line),
    boxShadow: const [
      BoxShadow(
        color: HomiziColors.shadowSoft,
        blurRadius: 10,
        offset: Offset(0, 3),
      ),
    ],
  );
}
