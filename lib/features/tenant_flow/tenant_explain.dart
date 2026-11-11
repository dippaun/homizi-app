import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_widgets.dart';
import 'package:homizi/features/tenant_flow/tenant_chrome.dart';
import 'package:homizi/features/tenant_flow/tenant_labels.dart';
import 'package:homizi/features/tenant_flow/tenant_order.dart';

class TenantIntroPage extends StatelessWidget {
  const TenantIntroPage({
    required this.onBack,
    required this.onNext,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-intro'),
      onBack: onBack,
      bottom: TenantNextButton(
        label: 'See how matching works',
        onPressed: onNext,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            homiziText(context, 'Smart Matching'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          Text(
            homiziText(context, 'for Better Living'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: HomiziColors.accent,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            homiziText(
              context,
              'Your priorities. Our intelligent matching. The right people, right places, happier living.',
            ),
            style: const TextStyle(
              color: HomiziColors.inkSoft,
              fontFamily: 'Inter',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          const TenantPoint(
            icon: Icons.favorite_border,
            label: 'Personalized Matches',
            color: HomiziColors.successWash,
            iconColor: HomiziColors.success,
          ),
          const TenantPoint(
            icon: Icons.schedule,
            label: 'Save Time and Effort',
            color: HomiziColors.accentWash,
          ),
          const TenantPoint(
            icon: Icons.verified_outlined,
            label: 'Verified Listings and Users',
            color: HomiziColors.successWash,
            iconColor: HomiziColors.success,
          ),
          const TenantPoint(
            icon: Icons.groups_outlined,
            label: 'Find Compatible Roomies',
            color: HomiziColors.accentWash,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: const SizedBox(
              height: 220,
              child: ListingPhoto(
                asset: 'assets/avatars/avatar_06.webp',
                semanticLabel: 'A tenant looking for a home',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: HomiziColors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              homiziText(
                context,
                "More than Just a Search. It's a Better Match!",
              ),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TenantPrioritiesExplainPage extends StatelessWidget {
  const TenantPrioritiesExplainPage({
    required this.onBack,
    required this.onNext,
    required this.tenant,
    required this.host,
    required this.side,
    required this.onSide,
    this.pageKey = const Key('tenant-flow-priorities-explain'),
    this.showToggle = true,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;
  final TenantPriorities tenant;
  final HostPriorities host;
  final MatchSide side;
  final ValueChanged<MatchSide> onSide;
  final Key pageKey;
  final bool showToggle;

  @override
  Widget build(BuildContext context) {
    final tenantSide = side == MatchSide.tenant;
    return TenantFlowScaffold(
      pageKey: pageKey,
      onBack: onBack,
      title: tenantSide ? 'Set Your Priorities' : 'Host Your Preferences',
      stepLabel: tenantSide ? '1/6' : '2/6',
      bottom: TenantNextButton(label: 'Continue', onPressed: onNext),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            homiziText(
              context,
              tenantSide
                  ? 'Rank what matters most to you. 1 = Highest priority · 8 = Lowest priority.'
                  : 'Find the right tenants or roomies for your property. Set what you are looking for.',
            ),
            style: const TextStyle(
              color: HomiziColors.inkSoft,
              fontFamily: 'Inter',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (showToggle) ...[
            TenantSideToggle(side: side, onChanged: onSide),
            const SizedBox(height: 12),
          ],
          if (tenantSide)
            for (var index = 0; index < tenant.order.length; index++)
              _RankPreview(
                rank: index + 1,
                icon: tenantFlowFactorIcon(tenant.order[index]),
                title: tenantFlowFactorTitle(tenant.order[index]),
                value: tenantFlowFactorValue(tenant, tenant.order[index]),
              )
          else
            for (var index = 0; index < host.order.length; index++)
              _RankPreview(
                rank: index + 1,
                icon: hostFlowFactorIcon(host.order[index]),
                title: hostFactorTitle(host.order[index]),
                value: hostFlowFactorValue(host, host.order[index]),
              ),
          const SizedBox(height: 8),
          if (tenantSide) ...const [
            TenantPoint(
              icon: Icons.low_priority,
              label: "Tell us what's important to you",
              color: HomiziColors.accentWash,
            ),
            TenantPoint(
              icon: Icons.tune,
              label: 'Must-have and flexible options',
              color: HomiziColors.successWash,
              iconColor: HomiziColors.success,
            ),
            TenantPoint(
              icon: Icons.swap_vert,
              label: 'Change any time',
              color: HomiziColors.mist,
            ),
            TenantPoint(
              icon: Icons.auto_awesome,
              label: 'Get better matches',
              color: HomiziColors.accentWash,
            ),
          ] else ...const [
            TenantPoint(
              icon: Icons.groups_outlined,
              label: 'Get tenants who match your lifestyle and rules',
              color: HomiziColors.accentWash,
            ),
            TenantPoint(
              icon: Icons.verified_outlined,
              label: 'Better quality tenants',
              color: HomiziColors.successWash,
              iconColor: HomiziColors.success,
            ),
            TenantPoint(
              icon: Icons.filter_alt_outlined,
              label: 'Less unwanted inquiries',
              color: HomiziColors.mist,
            ),
            TenantPoint(
              icon: Icons.schedule,
              label: 'Save time in screening',
              color: HomiziColors.accentWash,
            ),
          ],
        ],
      ),
    );
  }
}

class _RankPreview extends StatelessWidget {
  const _RankPreview({
    required this.rank,
    required this.icon,
    required this.title,
    required this.value,
  });

  final int rank;
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HomiziColors.line),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: HomiziColors.accent,
            foregroundColor: HomiziColors.ink,
            child: Text(
              '$rank',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, color: HomiziColors.ink, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, title),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                Text(
                  homiziText(context, value),
                  style: const TextStyle(
                    color: HomiziColors.muted,
                    fontFamily: 'Inter',
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Text(
            homiziText(context, 'Priority $rank'),
            style: const TextStyle(
              color: HomiziColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
        ],
      ),
    );
  }
}

class TenantHowPage extends StatelessWidget {
  const TenantHowPage({required this.onBack, required this.onNext, super.key});

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-how'),
      onBack: onBack,
      title: 'How Matching Works',
      stepLabel: '3/6',
      bottom: TenantNextButton(label: 'See match results', onPressed: onNext),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            homiziText(
              context,
              'We compare your priorities and preferences and show the most compatible results.',
            ),
            style: const TextStyle(
              color: HomiziColors.inkSoft,
              fontFamily: 'Inter',
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          const TenantNumberedStep(
            number: '1',
            title: 'You Set Priorities',
            detail: 'Tenant and host set and rank their preferences.',
            icon: Icons.format_list_numbered,
          ),
          const TenantNumberedStep(
            number: '2',
            title: 'Our System Compares',
            detail: 'We match both sides using the existing match score.',
            icon: Icons.compare_arrows,
          ),
          const TenantNumberedStep(
            number: '3',
            title: 'Compatibility Score',
            detail: 'Each match gets a score based on your priorities.',
            icon: Icons.speed,
          ),
          const TenantNumberedStep(
            number: '4',
            title: 'Get Best Matches First',
            detail:
                'Top compatible properties or tenants are shown first. Exact matches lead.',
            icon: Icons.bar_chart,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: const SizedBox(
              height: 160,
              child: ListingPhoto(
                asset: 'assets/images/home/roomies.jpg',
                semanticLabel: 'People finding a home together',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Right People. Right Places. Happier Living.'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class TenantResultsPage extends StatelessWidget {
  const TenantResultsPage({
    required this.onBack,
    required this.onNext,
    required this.properties,
    required this.roomies,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;
  final List<TenantFlowPick> properties;
  final List<TenantFlowPick> roomies;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-results'),
      onBack: onBack,
      title: 'Your Match Results',
      stepLabel: '4/6',
      bottom: TenantNextButton(label: 'Explain the score', onPressed: onNext),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                homiziText(context, 'See your most compatible matches first.'),
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const TabBar(
              labelColor: HomiziColors.ink,
              unselectedLabelColor: HomiziColors.muted,
              indicatorColor: HomiziColors.accent,
              tabs: [
                Tab(key: Key('tenant-tab-properties'), text: 'Properties'),
                Tab(key: Key('tenant-tab-roomies'), text: 'Roomies'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ResultList(picks: properties),
                  _ResultList(picks: roomies),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.picks});

  final List<TenantFlowPick> picks;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        for (final pick in picks.take(3)) ...[
          _ResultCard(pick: pick),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.pick});

  final TenantFlowPick pick;

  @override
  Widget build(BuildContext context) {
    final photo = pick.photos.isEmpty ? null : pick.photos.first;
    return Container(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HomiziColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListingPhoto(asset: photo, semanticLabel: pick.title),
                Positioned(
                  left: 8,
                  top: 8,
                  child: TenantMatchBadge(
                    percent: pick.percent,
                    importantMismatch: pick.importantMismatch,
                  ),
                ),
                if (pick.verified)
                  const Positioned(
                    right: 8,
                    top: 8,
                    child: TenantVerifiedBadge(),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, pick.title),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                Text(
                  homiziText(
                    context,
                    pick.priceLabel.isEmpty
                        ? pick.place
                        : '${pick.place} · ${pick.priceLabel}',
                  ),
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 8),
                TenantStoryBox(
                  title: pick.headline,
                  lines: pick.story,
                  strength: pick.strength,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TenantScorePage extends StatelessWidget {
  const TenantScorePage({
    required this.onBack,
    required this.onNext,
    required this.pick,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;
  final TenantFlowPick? pick;

  @override
  Widget build(BuildContext context) {
    final shown = pick;
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-score'),
      onBack: onBack,
      title: 'Match Score Explained',
      stepLabel: '5/6',
      bottom: TenantNextButton(label: 'Colour codes', onPressed: onNext),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            homiziText(
              context,
              'Understand why a property or tenant is recommended.',
            ),
            style: const TextStyle(
              color: HomiziColors.inkSoft,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          if (shown == null)
            Text(homiziText(context, 'No demo match is available.'))
          else ...[
            Center(child: TenantScoreRing(percent: shown.percent)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                homiziText(context, shown.title),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'PlusJakartaSans',
                ),
              ),
            ),
            Center(
              child: Text(
                homiziText(context, shown.place),
                style: const TextStyle(color: HomiziColors.muted),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              homiziText(context, 'Key Match Factors'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            for (final bar in shown.bars)
              FactorBar(label: bar.label, percent: bar.percent),
            const SizedBox(height: 8),
            Text(
              homiziText(
                context,
                'Total Compatibility Score = ${shown.percent}%',
              ),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontFamily: 'PlusJakartaSans',
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              homiziText(
                context,
                'Based on your priorities and listing quality. Verification is a badge, not part of the score.',
              ),
              style: const TextStyle(
                color: HomiziColors.inkSoft,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class TenantColourPage extends StatelessWidget {
  const TenantColourPage({
    required this.onBack,
    required this.onNext,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-colour'),
      onBack: onBack,
      title: 'Colour-Coded Matches',
      stepLabel: '6/6',
      bottom: TenantNextButton(label: 'Continue', onPressed: onNext),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Text(
            homiziText(context, 'Easily see which matches are best for you.'),
            style: const TextStyle(
              color: HomiziColors.inkSoft,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),
          const _Band(
            range: '70–100%',
            title: 'Strong Match',
            detail:
                'Most of your priorities match. Higher chance of compatibility. Recommended to contact.',
            strength: MatchStrength.strong,
            icon: Icons.home,
          ),
          const SizedBox(height: 12),
          const _Band(
            range: '40–69%',
            title: 'Partial Match',
            detail:
                'Some preferences match. Minor differences. Still worth considering.',
            strength: MatchStrength.partial,
            icon: Icons.home_outlined,
          ),
          const SizedBox(height: 12),
          const _Band(
            range: '0–39%',
            title: 'Low Match',
            detail:
                'Major preferences do not match. Misaligned with your needs. Shown for wider options only.',
            strength: MatchStrength.low,
            icon: Icons.home_outlined,
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              'A must-have miss stays in the low band, even when the percent is high.',
            ),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({
    required this.range,
    required this.title,
    required this.detail,
    required this.strength,
    required this.icon,
  });

  final String range;
  final String title;
  final String detail;
  final MatchStrength strength;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final wash = switch (strength) {
      MatchStrength.strong => HomiziColors.successWash,
      MatchStrength.partial => HomiziColors.warningWash,
      MatchStrength.low => HomiziColors.errorWash,
    };
    final mark = switch (strength) {
      MatchStrength.strong => HomiziColors.success,
      MatchStrength.partial => HomiziColors.warning,
      MatchStrength.low => HomiziColors.error,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: mark,
            foregroundColor: HomiziColors.white,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  range,
                  style: TextStyle(
                    color: mark,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                Text(
                  homiziText(context, title),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  homiziText(context, detail),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontFamily: 'Inter',
                    height: 1.3,
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

class TenantHappierPage extends StatelessWidget {
  const TenantHappierPage({
    required this.onBack,
    required this.onNext,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-happier'),
      onBack: onBack,
      bottom: TenantNextButton(
        label: 'Find Your Perfect Match',
        onPressed: onNext,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            homiziText(context, 'Better Matches'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          Text(
            homiziText(context, 'Happier People'),
            style: theme.textTheme.headlineMedium?.copyWith(
              color: HomiziColors.accent,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 16),
          const TenantPoint(
            icon: Icons.person_pin_circle_outlined,
            label: 'For Tenants',
            detail: 'Find properties and roommates that truly fit your needs.',
            color: HomiziColors.accentWash,
          ),
          const TenantPoint(
            icon: Icons.home_work_outlined,
            label: 'For Hosts',
            detail: 'Get compatible and reliable tenants or roomies.',
            color: HomiziColors.successWash,
            iconColor: HomiziColors.success,
          ),
          const TenantPoint(
            icon: Icons.bolt,
            label: 'Save Time',
            detail: 'Less irrelevant listings and inquiries.',
            color: HomiziColors.accentWash,
          ),
          const TenantPoint(
            icon: Icons.verified_user_outlined,
            label: 'Safe & Transparent',
            detail: 'Verified users, clear details, and personalised results.',
            color: HomiziColors.successWash,
            iconColor: HomiziColors.success,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HomiziColors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              homiziText(context, 'Find Your Perfect Match with Homizi'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontFamily: 'PlusJakartaSans',
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TenantJourneyHubPage extends StatelessWidget {
  const TenantJourneyHubPage({
    required this.onBack,
    required this.onNext,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-journey'),
      onBack: onBack,
      bottom: TenantNextButton(label: 'Set Your Priorities', onPressed: onNext),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HomiziColors.accent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Simple. Smart. Social.',
              style: TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontFamily: 'PlusJakartaSans',
                fontSize: 22,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Find the Right Place. Meet the Right People.'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HubChip('For Tenants'),
              _HubChip('For Hosts'),
              _HubChip('Smart Matching'),
              _HubChip('Verified & Safe'),
            ],
          ),
          const SizedBox(height: 16),
          const TenantNumberedStep(
            number: '1',
            title: 'Set Your Priorities',
            detail:
                'Rank what matters most to you. This helps us show your best matches first.',
          ),
          const TenantNumberedStep(
            number: '2',
            title: 'Browse Best Matches',
            detail:
                'See top compatible listings in a list, with match % and Verified.',
          ),
          const TenantNumberedStep(
            number: '3',
            title: 'Tinder-Style Matching',
            detail: 'Swipe to find your best matches quickly and easily.',
          ),
          const TenantNumberedStep(
            number: '4',
            title: 'Detailed View',
            detail: 'View full details, photos, amenities, rules and more.',
          ),
          const TenantNumberedStep(
            number: '5',
            title: "It's a Match!",
            detail: 'When both sides are interested, a match is created.',
          ),
          const TenantNumberedStep(
            number: '6',
            title: 'Chat & Book Visit',
            detail:
                'Chat, share necessary details, and schedule a property visit.',
          ),
          const SizedBox(height: 8),
          const TenantFeatureStrip(),
        ],
      ),
    );
  }
}

class _HubChip extends StatelessWidget {
  const _HubChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(homiziText(context, label)),
      backgroundColor: HomiziColors.white,
      side: const BorderSide(color: HomiziColors.line),
      labelStyle: const TextStyle(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
