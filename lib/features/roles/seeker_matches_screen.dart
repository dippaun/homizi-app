import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/layout/homizi_frame.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/homizi_home_bar.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/roles/seeker_providers.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';
import 'package:homizi/features/seekers/seeker_board.dart';
import 'package:homizi/features/seekers/seeker_contact.dart';
import 'package:homizi/features/seekers/seeker_preview_screen.dart';
import 'package:homizi/features/seekers/seeker_score.dart';
import 'package:homizi/features/seekers/seeker_shortlist.dart';

class SeekerMatchesScreen extends ConsumerStatefulWidget {
  const SeekerMatchesScreen({
    required this.title,
    this.showBrokerBadge = false,
    this.topMatches = false,
    super.key,
  });

  /// Kept so existing call sites still compile. The visible heading is
  /// Interested Seekers.
  final String title;
  final bool showBrokerBadge;

  /// "Top match profiles": Top matches / Other profiles, ranked by the
  /// host's saved preferred tenant profile.
  final bool topMatches;

  @override
  ConsumerState<SeekerMatchesScreen> createState() =>
      _SeekerMatchesScreenState();
}

class _SeekerMatchesScreenState extends ConsumerState<SeekerMatchesScreen> {
  List<HostProperty> _properties = const [];
  List<SeekerPublicProfile> _seekers = const [];
  String? _propertyId;
  SeekerListFilter _filter = const SeekerListFilter();
  SeekerTab _tab = SeekerTab.all;
  var _topTab = 0;
  String? _error;
  var _loading = true;
  var _gatewayEmpty = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(seekerMatchGatewayProvider).load();
      if (!mounted) {
        return;
      }
      final owned = ref.read(demoListingMemoryProvider).homes.values;
      final published = ref.read(publishedSearchProvider);
      final properties = collectHostProperties(
        owned: owned,
        published: published,
      );
      final query = GoRouter.maybeOf(
        context,
      )?.routeInformationProvider.value.uri.queryParameters['listing'];
      // Top match profiles open on the home the priorities were set for.
      final ranked = ref.read(hostTenantPrioritiesProvider);
      final selected = preferredPropertyId(
        properties,
        queryId:
            query ??
            (widget.topMatches && ranked.saved ? ranked.propertyId : null),
      );
      setState(() {
        _properties = properties;
        _seekers = [
          for (final seeker in page.seekers) profileFromMatch(seeker),
        ];
        _propertyId = selected;
        _gatewayEmpty = page.seekers.isEmpty;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'The seeker list could not be loaded.';
        _loading = false;
      });
    }
  }

  HostProperty? get _property {
    for (final item in _properties) {
      if (item.id == _propertyId) {
        return item;
      }
    }
    return _properties.isEmpty ? null : _properties.first;
  }

  @override
  Widget build(BuildContext context) {
    final deck = ref.watch(seekerDeckProvider);
    final session = ref.watch(matchControllerProvider);
    final hostPriorities = ref.watch(hostTenantPrioritiesProvider);
    final property = _property;
    final all = property == null
        ? const <ScoredSeeker>[]
        : scoreSeekers(
            seekers: _seekers,
            property: property,
            filter: _filter,
            dismissed: deck.dismissed,
            priorities: savedHostPriorities(session.host),
            signals: session.signals,
            hostPriorities: hostPriorities,
          );
    // Interested Seekers leaves out anyone who misses a must-have, as
    // before. Top match profiles shows them under Other profiles.
    final scored = widget.topMatches
        ? all
        : [
            for (final row in all)
              if (!(row.priorityMatch?.missesMustHave ?? false)) row,
          ];
    final top = [
      for (final row in scored)
        if (row.isTopMatch) row,
    ];
    final others = [
      for (final row in scored)
        if (!row.isTopMatch) row,
    ];
    final visible = widget.topMatches
        ? (_topTab == 0 ? top : others)
        : seekersForTab(scored, _tab, deck.shortlisted);
    final best = seekersForTab(scored, SeekerTab.best, deck.shortlisted).length;
    final shortCount = scored
        .where((row) => deck.shortlisted.contains(row.profile.id))
        .length;
    return Scaffold(
      key: const Key('interested-seekers'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        foregroundColor: HomiziColors.ink,
        elevation: 0,
        leading: const HomiziBackButton(key: Key('seekers-back')),
        title: const HomiziLockup(),
        actions: [
          if (widget.showBrokerBadge)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Center(child: BrokerChip()),
            ),
          IconButton(
            key: const Key('seekers-bell'),
            tooltip: homiziText(context, 'Notifications'),
            onPressed: () {
              final router = GoRouter.maybeOf(context);
              if (router != null) {
                router.push(RoutePaths.notifications);
              }
            },
            icon: const Icon(Icons.notifications_none, color: HomiziColors.ink),
          ),
          IconButton(
            key: const Key('seekers-open-shortlist'),
            tooltip: homiziText(context, 'Shortlisted'),
            onPressed: () => setState(() => _tab = SeekerTab.shortlisted),
            icon: const Icon(Icons.favorite_border, color: HomiziColors.ink),
          ),
        ],
      ),
      body: HomiziFrame(
        child: _loading
            ? const LoadingState(message: 'Finding seekers…')
            : _error != null
            ? ErrorState(
                title: 'Seekers unavailable',
                message: _error!,
                onRetry: () => unawaited(_load()),
              )
            : _gatewayEmpty
            ? EmptyState(
                key: const Key('seekers-empty'),
                title: 'No matching seekers yet',
                message: 'No discoverable briefs match your listings yet.',
                actionLabel: 'Post a listing',
                onAction: () => context.go(RoutePaths.listingEditor),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      key: const Key('seekers-shot'),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        Text(
                          homiziText(
                            context,
                            widget.topMatches
                                ? 'Top match profiles'
                                : 'Interested Seekers',
                          ),
                          key: const Key('seekers-heading'),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: HomiziColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          homiziText(
                            context,
                            widget.topMatches
                                ? hostPriorities.saved
                                      ? 'Ranked by your priorities'
                                      : 'Ranked by your listing until you set priorities'
                                : 'People looking for a place like yours',
                          ),
                          style: const TextStyle(color: HomiziColors.muted),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          homiziText(
                            context,
                            'Contact stays hidden until you both match and they share it.',
                          ),
                          style: const TextStyle(
                            color: HomiziColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        if (property != null && property.sample) ...[
                          const SizedBox(height: 8),
                          Text(
                            homiziText(
                              context,
                              'Sample home until you publish a listing. Match scores use that sample.',
                            ),
                            style: const TextStyle(
                              color: HomiziColors.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (property != null)
                          _Selectors(
                            properties: _properties,
                            selected: property,
                            filterOn: !_filter.isDefault,
                            onCity: (city) {
                              final next = propertyInCity(_properties, city);
                              setState(() => _propertyId = next.id);
                            },
                            onProperty: (id) =>
                                setState(() => _propertyId = id),
                            onFilter: () => unawaited(_openFilter()),
                          ),
                        const SizedBox(height: 12),
                        if (widget.topMatches && !hostPriorities.saved)
                          _SetPrioritiesBanner(
                            onTap: () =>
                                context.push(RoutePaths.hostPriorities),
                          ),
                        if (widget.topMatches)
                          _TopTabs(
                            index: _topTab,
                            top: top.length,
                            others: others.length,
                            onChanged: (value) =>
                                setState(() => _topTab = value),
                          )
                        else
                          _TabBar(
                            tab: _tab,
                            all: scored.length,
                            best: best,
                            shortlisted: shortCount,
                            onChanged: (tab) => setState(() => _tab = tab),
                          ),
                        const SizedBox(height: 12),
                        if (visible.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              homiziText(
                                context,
                                widget.topMatches && _topTab == 0
                                    ? 'No seeker meets every must-have yet. See Other profiles, or make a priority flexible.'
                                    : _tab == SeekerTab.shortlisted
                                    ? 'No shortlisted seekers for this home yet.'
                                    : 'No seekers in this view.',
                              ),
                              key: const Key('seekers-tab-empty'),
                              style: const TextStyle(color: HomiziColors.muted),
                            ),
                          )
                        else
                          for (final row in visible)
                            if (widget.topMatches)
                              _TopSeekerCard(
                                row: row,
                                saved: deck.shortlisted.contains(
                                  row.profile.id,
                                ),
                                onSave: () => ref
                                    .read(seekerDeckProvider.notifier)
                                    .toggleShortlist(row.profile.id),
                                onOpen: () => _open(row, property!),
                              )
                            else
                              _SeekerCard(
                                row: row,
                                saved: deck.shortlisted.contains(
                                  row.profile.id,
                                ),
                                onSave: () => ref
                                    .read(seekerDeckProvider.notifier)
                                    .toggleShortlist(row.profile.id),
                                onOpen: () => _open(row, property!),
                              ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _openFilter() async {
    final next = await showModalBottomSheet<SeekerListFilter>(
      context: context,
      backgroundColor: HomiziColors.white,
      builder: (context) => _FilterSheet(initial: _filter),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() => _filter = next);
  }

  void _open(ScoredSeeker row, HostProperty property) {
    final args = SeekerPreviewArgs(
      profile: row.profile,
      property: property,
      fit: row.fit,
    );
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push(RoutePaths.seekerPreview(row.profile.id), extra: args);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            SeekerPreviewScreen(requirementId: row.profile.id, args: args),
      ),
    );
  }
}

class _Selectors extends StatelessWidget {
  const _Selectors({
    required this.properties,
    required this.selected,
    required this.filterOn,
    required this.onCity,
    required this.onProperty,
    required this.onFilter,
  });

  final List<HostProperty> properties;
  final HostProperty selected;
  final bool filterOn;
  final ValueChanged<String> onCity;
  final ValueChanged<String> onProperty;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final cities = <String>[];
    for (final item in properties) {
      if (!cities.any((city) => sameSeekerCity(city, item.city))) {
        cities.add(item.city);
      }
    }
    cities.sort();
    final inCity = [
      for (final item in properties)
        if (sameSeekerCity(item.city, selected.city)) item,
    ];
    return Row(
      children: [
        _MenuChip(
          menuKey: const Key('seeker-city'),
          icon: Icons.location_on_outlined,
          label: selected.city,
          expand: false,
          items: [
            for (final city in cities)
              PopupMenuItem<String>(
                key: Key('seeker-city-$city'),
                value: city,
                child: Text(homiziText(context, city)),
              ),
          ],
          onSelected: onCity,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MenuChip(
            menuKey: const Key('seeker-listing'),
            icon: Icons.home_outlined,
            label: selected.label,
            items: [
              for (final item in inCity)
                PopupMenuItem<String>(
                  key: Key('seeker-listing-${item.id}'),
                  value: item.id,
                  child: Text(homiziText(context, item.label)),
                ),
            ],
            onSelected: onProperty,
          ),
        ),
        IconButton(
          key: const Key('seeker-filter'),
          tooltip: homiziText(context, 'Filter'),
          onPressed: onFilter,
          style: IconButton.styleFrom(
            backgroundColor: filterOn
                ? HomiziColors.accentWash
                : HomiziColors.soft,
            foregroundColor: HomiziColors.ink,
          ),
          icon: const Icon(Icons.tune),
        ),
      ],
    );
  }
}

class _MenuChip extends StatelessWidget {
  const _MenuChip({
    required this.menuKey,
    required this.icon,
    required this.label,
    required this.items,
    required this.onSelected,
    this.expand = true,
  });

  final Key menuKey;
  final IconData icon;
  final String label;
  final List<PopupMenuEntry<String>> items;
  final ValueChanged<String> onSelected;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      homiziText(context, label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
    return PopupMenuButton<String>(
      key: menuKey,
      onSelected: onSelected,
      itemBuilder: (context) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: HomiziColors.soft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: HomiziColors.logoOrange),
            const SizedBox(width: 6),
            if (expand) Expanded(child: text) else text,
            const Icon(Icons.expand_more, size: 18, color: HomiziColors.muted),
          ],
        ),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.tab,
    required this.all,
    required this.best,
    required this.shortlisted,
    required this.onChanged,
  });

  final SeekerTab tab;
  final int all;
  final int best;
  final int shortlisted;
  final ValueChanged<SeekerTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Tab(
          tabKey: const Key('seeker-tab-all'),
          label: 'All Seekers ($all)',
          selected: tab == SeekerTab.all,
          onTap: () => onChanged(SeekerTab.all),
        ),
        _Tab(
          tabKey: const Key('seeker-tab-best'),
          label: 'Best Matches ($best)',
          selected: tab == SeekerTab.best,
          onTap: () => onChanged(SeekerTab.best),
        ),
        _Tab(
          tabKey: const Key('seeker-tab-shortlist'),
          label: 'Shortlisted ($shortlisted)',
          selected: tab == SeekerTab.shortlisted,
          onTap: () => onChanged(SeekerTab.shortlisted),
        ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.tabKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key tabKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected ? HomiziColors.white : HomiziColors.clear,
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: HomiziColors.shadow,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: InkWell(
            key: tabKey,
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Text(
                homiziText(context, label),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? HomiziColors.ink : HomiziColors.muted,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SeekerCard extends StatelessWidget {
  const _SeekerCard({
    required this.row,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });

  final ScoredSeeker row;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final profile = row.profile;
    final budget =
        '${formatInr(profile.budgetMinInr)} – ${formatInr(profile.budgetMaxInr)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: Key('seeker-card-${profile.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: HomiziColors.line),
            ),
            child: Row(
              children: [
                Hero(
                  tag: 'seeker-photo-${profile.id}',
                  child: _Face(profile: profile),
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
                              style: const TextStyle(
                                color: HomiziColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (profile.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: HomiziColors.success,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        homiziText(
                          context,
                          [
                            if (profile.age != null) '${profile.age}',
                            profile.occupationLabel,
                          ].join(' · '),
                        ),
                        style: const TextStyle(
                          color: HomiziColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        homiziText(context, budget),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontWeight: FontWeight.w700,
                          color: HomiziColors.inkSoft,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  key: Key('seeker-match-${profile.id}'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: HomiziColors.successWash,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${row.fit.percent}%',
                    style: const TextStyle(
                      color: HomiziColors.success,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                IconButton(
                  key: Key('seeker-shortlist-${profile.id}'),
                  onPressed: onSave,
                  icon: Icon(
                    saved ? Icons.favorite : Icons.favorite_border,
                    color: saved ? HomiziColors.logoOrange : HomiziColors.muted,
                  ),
                ),
                const Icon(Icons.chevron_right, color: HomiziColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.profile});

  final SeekerPublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final asset = profile.photoAsset;
    return CircleAvatar(
      radius: 26,
      backgroundColor: HomiziColors.accentWash,
      backgroundImage: asset.isEmpty ? null : AssetImage(asset),
      child: asset.isEmpty
          ? Text(
              profile.name.isEmpty ? '?' : profile.name.substring(0, 1),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            )
          : null,
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final SeekerListFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late SeekerListFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, 'Filter seekers'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('seeker-filter-verified'),
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Verified seekers')),
            value: _draft.verifiedOnly,
            activeThumbColor: HomiziColors.success,
            onChanged: (value) =>
                setState(() => _draft = _draft.copyWith(verifiedOnly: value)),
          ),
          SwitchListTile(
            key: const Key('seeker-filter-budget'),
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Budget covers this rent')),
            value: _draft.budgetFits,
            activeThumbColor: HomiziColors.success,
            onChanged: (value) =>
                setState(() => _draft = _draft.copyWith(budgetFits: value)),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Profession'),
            style: const TextStyle(color: HomiziColors.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final item in const ['any', 'working', 'student'])
                ChoiceChip(
                  key: Key('seeker-filter-$item'),
                  label: Text(
                    homiziText(
                      context,
                      item == 'any'
                          ? 'Any'
                          : item == 'working'
                          ? 'Working'
                          : 'Student',
                    ),
                  ),
                  selected: _draft.profession == item,
                  onSelected: (_) => setState(
                    () => _draft = _draft.copyWith(profession: item),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('seeker-filter-apply'),
            style: FilledButton.styleFrom(
              backgroundColor: HomiziColors.accent,
              foregroundColor: HomiziColors.ink,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => Navigator.of(context).pop(_draft),
            child: Text(homiziText(context, 'Apply')),
          ),
        ],
      ),
    );
  }
}

class _SetPrioritiesBanner extends StatelessWidget {
  const _SetPrioritiesBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const Key('seekers-set-priorities'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.tune, color: HomiziColors.logoOrange),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    homiziText(
                      context,
                      'Set your priorities (budget, move-in, working professional, food, gender & age) to rank these profiles your way.',
                    ),
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: HomiziColors.ink),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({
    required this.index,
    required this.top,
    required this.others,
    required this.onChanged,
  });

  final int index;
  final int top;
  final int others;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(int i, String label, Key key) {
      final selected = index == i;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Material(
            color: selected ? null : HomiziColors.soft,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: selected
                  ? BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          HomiziColors.logoOrange,
                          HomiziColors.brandRedOrange,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: InkWell(
                key: key,
                borderRadius: BorderRadius.circular(14),
                onTap: () => onChanged(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Text(
                    homiziText(context, label),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? HomiziColors.white : HomiziColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(0, 'Top matches ($top)', const Key('seeker-tab-top')),
        tab(1, 'Other profiles ($others)', const Key('seeker-tab-other')),
      ],
    );
  }
}

class _TopSeekerCard extends StatelessWidget {
  const _TopSeekerCard({
    required this.row,
    required this.saved,
    required this.onSave,
    required this.onOpen,
  });

  final ScoredSeeker row;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final profile = row.profile;
    final veg = profile.wantsNonVeg
        ? 'No'
        : profile.lifestyleKnown
        ? 'Yes'
        : 'Not shared';
    final moveIn = profile.moveInLabel.trim().isNotEmpty
        ? profile.moveInLabel.trim()
        : 'Not shared';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: row.isTopMatch
                ? HomiziColors.brandOrange
                : HomiziColors.line,
          ),
        ),
        child: InkWell(
          key: Key('seeker-card-${profile.id}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _Face(profile: profile),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            homiziText(context, profile.name),
                            style: const TextStyle(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            homiziText(
                              context,
                              [
                                profile.occupationLabel,
                                if (profile.age != null) '${profile.age} yrs',
                              ].join(' · '),
                            ),
                            style: const TextStyle(
                              color: HomiziColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      key: Key('seeker-match-${profile.id}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: HomiziColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${row.fit.percent}% ${homiziText(context, 'Match')}',
                        style: const TextStyle(
                          color: HomiziColors.onSuccess,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      key: Key('seeker-shortlist-${profile.id}'),
                      tooltip: homiziText(context, 'Shortlist'),
                      onPressed: onSave,
                      icon: Icon(
                        saved ? Icons.favorite : Icons.favorite_border,
                        color: saved
                            ? HomiziColors.logoOrange
                            : HomiziColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _Fact(
                      icon: Icons.currency_rupee,
                      label: 'Budget',
                      value: formatInr(profile.budgetMaxInr),
                    ),
                    _Fact(
                      icon: Icons.bed_outlined,
                      label: 'Occupancy',
                      value: profile.propertyLine,
                    ),
                    _Fact(
                      icon: Icons.calendar_month_outlined,
                      label: 'Move-in',
                      value: moveIn,
                    ),
                    _Fact(
                      icon: Icons.eco_outlined,
                      label: 'Vegetarian',
                      value: veg,
                    ),
                  ],
                ),
                if (row.priorityMatch?.missesMustHave ?? false) ...[
                  const SizedBox(height: 6),
                  Text(
                    homiziText(context, 'Misses a must-have'),
                    key: Key('seeker-must-miss-${profile.id}'),
                    style: const TextStyle(
                      color: HomiziColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SeekerContactButtons(
                  profile: profile,
                  keyPrefix: 'seeker',
                  onChat: onOpen,
                ),
              ],
            ),
          ),
        ),
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
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: HomiziColors.logoOrange),
          Text(
            homiziText(context, label),
            style: const TextStyle(color: HomiziColors.muted, fontSize: 10),
          ),
          Text(
            homiziText(context, value),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
