import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/matching/match_widgets.dart';
import 'package:homizi/features/nearby/nearby_places_preview.dart';
import 'package:homizi/features/tenant_flow/tenant_chrome.dart';
import 'package:homizi/features/tenant_flow/tenant_labels.dart';
import 'package:homizi/features/tenant_flow/tenant_order.dart';

class TenantRankPage extends StatelessWidget {
  const TenantRankPage({
    required this.onBack,
    required this.onSave,
    required this.side,
    required this.tenant,
    required this.host,
    required this.onSide,
    required this.onReorderTenant,
    required this.onReorderHost,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onSave;
  final MatchSide side;
  final TenantPriorities tenant;
  final HostPriorities host;
  final ValueChanged<MatchSide> onSide;
  final void Function(int oldIndex, int newIndex) onReorderTenant;
  final void Function(int oldIndex, int newIndex) onReorderHost;

  @override
  Widget build(BuildContext context) {
    final tenantSide = side == MatchSide.tenant;
    final count = tenantSide ? tenant.order.length : host.order.length;
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-rank'),
      onBack: onBack,
      title: 'Set Your Priorities',
      stepLabel: '1',
      bottom: TenantNextButton(
        label: tenantSide ? 'Save Priorities' : 'Save Preferences',
        onPressed: onSave,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(
                    context,
                    'Drag to rank (1 = Highest). Exact matches on your top ranks are shown first.',
                  ),
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    fontFamily: 'Inter',
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                TenantSideToggle(side: side, onChanged: onSide),
                const SizedBox(height: 8),
                Text(
                  homiziText(context, '$count priorities'),
                  style: const TextStyle(
                    color: HomiziColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView(
              key: Key('tenant-priority-list-${side.name}'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              buildDefaultDragHandles: false,
              onReorderItem: tenantSide ? onReorderTenant : onReorderHost,
              children: [
                if (tenantSide)
                  for (var index = 0; index < tenant.order.length; index++)
                    _DragRow(
                      key: ValueKey('tenant-${tenant.order[index].name}'),
                      index: index,
                      icon: tenantFlowFactorIcon(tenant.order[index]),
                      title: tenantFlowFactorTitle(tenant.order[index]),
                      value: tenantFlowFactorValue(tenant, tenant.order[index]),
                    )
                else
                  for (var index = 0; index < host.order.length; index++)
                    _DragRow(
                      key: ValueKey('host-${host.order[index].name}'),
                      index: index,
                      icon: hostFlowFactorIcon(host.order[index]),
                      title: hostFactorTitle(host.order[index]),
                      value: hostFlowFactorValue(host, host.order[index]),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DragRow extends StatelessWidget {
  const _DragRow({
    required super.key,
    required this.index,
    required this.icon,
    required this.title,
    required this.value,
  });

  final int index;
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: HomiziColors.line),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle, color: HomiziColors.muted),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: HomiziColors.accent,
                foregroundColor: HomiziColors.ink,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 20, color: HomiziColors.ink),
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
            ],
          ),
        ),
      ),
    );
  }
}

enum TenantBrowseFilter { all, budget, location, verified }

class TenantBrowsePage extends StatefulWidget {
  const TenantBrowsePage({
    required this.onBack,
    required this.onSwipe,
    required this.picks,
    required this.onSkip,
    required this.onSave,
    required this.onInterested,
    required this.savedIds,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onSwipe;
  final List<TenantFlowPick> picks;
  final ValueChanged<TenantFlowPick> onSkip;
  final ValueChanged<TenantFlowPick> onSave;
  final ValueChanged<TenantFlowPick> onInterested;
  final Set<String> savedIds;

  @override
  State<TenantBrowsePage> createState() => _TenantBrowsePageState();
}

class _TenantBrowsePageState extends State<TenantBrowsePage> {
  final _query = TextEditingController();
  var _filter = TenantBrowseFilter.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _query.text.trim().toLowerCase();
    final shown = [
      for (final pick in widget.picks)
        if (_keeps(pick, text)) pick,
    ];
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-browse'),
      onBack: widget.onBack,
      title: 'Browse Best Matches',
      stepLabel: '2',
      bottom: TenantNextButton(
        label: 'Tinder-Style Matching',
        onPressed: widget.onSwipe,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const Key('tenant-browse-search'),
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: homiziText(
                      context,
                      'Search by location, locality or landmark',
                    ),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final filter in TenantBrowseFilter.values)
                      FilterChip(
                        key: Key('tenant-filter-${filter.name}'),
                        label: Text(homiziText(context, _filterLabel(filter))),
                        selected: _filter == filter,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      homiziText(context, 'No matches for this filter.'),
                      style: const TextStyle(color: HomiziColors.ink),
                    ),
                  )
                : ListView(
                    key: const Key('tenant-browse-list'),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      for (final pick in shown) ...[
                        _BrowseCard(
                          pick: pick,
                          saved: widget.savedIds.contains(pick.id),
                          onSkip: () => widget.onSkip(pick),
                          onSave: () => widget.onSave(pick),
                          onInterested: () => widget.onInterested(pick),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  bool _keeps(TenantFlowPick pick, String text) {
    if (text.isNotEmpty &&
        !pick.title.toLowerCase().contains(text) &&
        !pick.place.toLowerCase().contains(text)) {
      return false;
    }
    return switch (_filter) {
      TenantBrowseFilter.all => true,
      TenantBrowseFilter.budget => pick.withinBudget,
      TenantBrowseFilter.location => pick.preferredLocation,
      TenantBrowseFilter.verified => pick.verified,
    };
  }
}

String _filterLabel(TenantBrowseFilter filter) {
  return switch (filter) {
    TenantBrowseFilter.all => 'All',
    TenantBrowseFilter.budget => 'Budget',
    TenantBrowseFilter.location => 'Location',
    TenantBrowseFilter.verified => 'Verified',
  };
}

class _BrowseCard extends StatelessWidget {
  const _BrowseCard({
    required this.pick,
    required this.saved,
    required this.onSkip,
    required this.onSave,
    required this.onInterested,
  });

  final TenantFlowPick pick;
  final bool saved;
  final VoidCallback onSkip;
  final VoidCallback onSave;
  final VoidCallback onInterested;

  @override
  Widget build(BuildContext context) {
    final photo = pick.photos.isEmpty ? null : pick.photos.first;
    return Container(
      key: Key('tenant-card-${pick.id}'),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HomiziColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 150,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListingPhoto(asset: photo, semanticLabel: pick.title),
                Positioned(
                  left: 10,
                  top: 10,
                  child: TenantMatchBadge(
                    percent: pick.percent,
                    importantMismatch: pick.importantMismatch,
                  ),
                ),
                if (pick.verified)
                  const Positioned(
                    right: 10,
                    top: 10,
                    child: TenantVerifiedBadge(),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  homiziText(context, pick.title),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    fontFamily: 'PlusJakartaSans',
                  ),
                ),
                Text(
                  homiziText(context, pick.place),
                  style: const TextStyle(
                    color: HomiziColors.inkSoft,
                    fontFamily: 'Inter',
                  ),
                ),
                if (pick.priceLabel.isNotEmpty)
                  Text(
                    homiziText(context, pick.priceLabel),
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                const SizedBox(height: 8),
                TenantStoryBox(
                  title: pick.strength.name == 'strong'
                      ? 'Your Top Preferences Match'
                      : pick.headline,
                  lines: pick.story,
                  strength: pick.strength,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    IconButton(
                      key: Key('tenant-skip-${pick.id}'),
                      tooltip: 'Skip',
                      onPressed: onSkip,
                      icon: const Icon(Icons.close),
                    ),
                    IconButton(
                      key: Key('tenant-save-${pick.id}'),
                      tooltip: saved ? 'Saved' : 'Save',
                      onPressed: onSave,
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border,
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: Key('tenant-interested-${pick.id}'),
                      onPressed: onInterested,
                      child: Text(homiziText(context, 'Interested')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TenantDetailPage extends StatefulWidget {
  const TenantDetailPage({
    required this.pick,
    required this.onBack,
    required this.onChat,
    required this.onInterested,
    super.key,
  });

  final TenantFlowPick pick;
  final VoidCallback onBack;
  final VoidCallback onChat;
  final VoidCallback onInterested;

  @override
  State<TenantDetailPage> createState() => _TenantDetailPageState();
}

String _localityOf(String place) {
  final parts = place
      .split(RegExp(r'[,·]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '';
  }
  return parts.first;
}

String _cityOf(String place) {
  final parts = place
      .split(RegExp(r'[,·]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length < 2) {
    return '';
  }
  return parts.last;
}

class _TenantDetailPageState extends State<TenantDetailPage> {
  var _photo = 0;

  @override
  Widget build(BuildContext context) {
    final pick = widget.pick;
    final photos = pick.photos.isEmpty ? const <String>[''] : pick.photos;
    final index = _photo.clamp(0, photos.length - 1);
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-detail'),
      onBack: widget.onBack,
      title: 'Detailed View',
      stepLabel: '4',
      bottom: TenantNextButton(
        label: 'Interested',
        onPressed: widget.onInterested,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 220,
              child: PageView.builder(
                key: const Key('tenant-photos'),
                itemCount: photos.length,
                onPageChanged: (value) => setState(() => _photo = value),
                itemBuilder: (context, page) {
                  return ListingPhoto(
                    asset: photos[page].isEmpty ? null : photos[page],
                    semanticLabel: pick.title,
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, tenantPhotoCaption(index, photos.length)),
            style: const TextStyle(
              color: HomiziColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TenantMatchBadge(
                percent: pick.percent,
                importantMismatch: pick.importantMismatch,
              ),
              if (pick.verified) const TenantVerifiedBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, pick.title),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          Text(
            homiziText(context, pick.place),
            style: const TextStyle(color: HomiziColors.inkSoft),
          ),
          const SizedBox(height: 12),
          NearbyPlacesPreview(
            cacheKey: pick.id,
            locality: _localityOf(pick.place),
            city: _cityOf(pick.place),
          ),
          if (pick.priceLabel.isNotEmpty)
            Text(
              homiziText(context, pick.priceLabel),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                fontFamily: 'PlusJakartaSans',
              ),
            ),
          if (pick.chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final chip in pick.chips)
                  Chip(label: Text(homiziText(context, chip))),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TenantStoryBox(
            title: 'Your Top Preferences',
            lines: pick.reasons.isEmpty ? pick.story : pick.reasons,
            strength: pick.strength,
          ),
          if (pick.differences.isNotEmpty) ...[
            const SizedBox(height: 8),
            TenantStoryBox(
              title: 'Some differences',
              lines: pick.differences,
              strength: MatchStrength.partial,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Key match factors'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          for (final bar in pick.bars)
            FactorBar(label: bar.label, percent: bar.percent),
          Text(
            homiziText(context, 'Total compatibility ${pick.percent}%'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _OwnerCard(pick: pick, onChat: widget.onChat),
          if (pick.about.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              homiziText(context, pick.about),
              style: const TextStyle(
                color: HomiziColors.inkSoft,
                fontFamily: 'Inter',
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OwnerCard extends StatelessWidget {
  const _OwnerCard({required this.pick, required this.onChat});

  final TenantFlowPick pick;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.mist,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 52,
                height: 52,
                child: ListingPhoto(
                  asset: pick.portrait,
                  semanticLabel: pick.personName,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, pick.personName),
                    style: const TextStyle(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    homiziText(context, pick.personRole),
                    style: const TextStyle(
                      color: HomiziColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (pick.verified)
              const Icon(Icons.verified, color: HomiziColors.success),
            IconButton(
              key: const Key('tenant-detail-chat'),
              onPressed: onChat,
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: HomiziColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TenantMatchPage extends StatelessWidget {
  const TenantMatchPage({
    required this.pick,
    required this.onBack,
    required this.onChat,
    required this.onContact,
    required this.onVisit,
    super.key,
  });

  final TenantFlowPick pick;
  final VoidCallback onBack;
  final VoidCallback onChat;
  final VoidCallback onContact;
  final VoidCallback onVisit;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-match'),
      onBack: onBack,
      title: "It's a Match",
      stepLabel: '5',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Face(
                asset: pick.photos.isEmpty ? pick.portrait : pick.photos.first,
                label: pick.title,
              ),
              const SizedBox(width: 12),
              const CircleAvatar(
                radius: 22,
                backgroundColor: HomiziColors.accent,
                child: Icon(Icons.favorite, color: HomiziColors.ink),
              ),
              const SizedBox(width: 12),
              _Face(asset: pick.portrait, label: pick.personName),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            homiziText(context, "It's a Match!"),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'You and ${pick.personName} are interested in each other.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: HomiziColors.inkSoft,
              fontFamily: 'Inter',
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TenantMatchBadge(
              percent: pick.percent,
              importantMismatch: pick.importantMismatch,
            ),
          ),
          const SizedBox(height: 20),
          TenantNextButton(label: 'Start Chat', onPressed: onChat),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('tenant-view-contact'),
            onPressed: onContact,
            child: Text(homiziText(context, 'View Contact Details')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('tenant-book-visit'),
            onPressed: onVisit,
            child: Text(homiziText(context, 'Book a Visit')),
          ),
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.asset, required this.label});

  final String asset;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 96,
        height: 96,
        child: ListingPhoto(asset: asset, semanticLabel: label),
      ),
    );
  }
}

class TenantChatPage extends StatefulWidget {
  const TenantChatPage({
    required this.pick,
    required this.messages,
    required this.onBack,
    required this.onSend,
    required this.onContact,
    required this.onVisit,
    required this.onDocs,
    super.key,
  });

  final TenantFlowPick pick;
  final List<MatchMessage> messages;
  final VoidCallback onBack;
  final ValueChanged<String> onSend;
  final VoidCallback onContact;
  final VoidCallback onVisit;
  final VoidCallback onDocs;

  @override
  State<TenantChatPage> createState() => _TenantChatPageState();
}

class _TenantChatPageState extends State<TenantChatPage> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pick = widget.pick;
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-chat'),
      onBack: widget.onBack,
      title: 'Chat & Book Visit',
      stepLabel: '6',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: ListingPhoto(
                      asset: pick.portrait,
                      semanticLabel: pick.personName,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, pick.personName),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        homiziText(
                          context,
                          pick.priceLabel.isEmpty
                              ? pick.title
                              : '${pick.title} · ${pick.priceLabel}',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: HomiziColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pick.verified) const TenantVerifiedBadge(),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              key: const Key('tenant-chat-list'),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final message in widget.messages)
                  Align(
                    alignment: message.fromSelf
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 280),
                      decoration: BoxDecoration(
                        color: message.fromSelf
                            ? HomiziColors.accentWash
                            : HomiziColors.mist,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        homiziText(context, message.body),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('tenant-share-contact'),
                  onPressed: widget.onContact,
                  icon: const Icon(Icons.contact_page_outlined, size: 18),
                  label: Text(homiziText(context, 'Share Contact')),
                ),
                OutlinedButton.icon(
                  key: const Key('tenant-schedule-visit'),
                  onPressed: widget.onVisit,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(homiziText(context, 'Schedule Visit')),
                ),
                OutlinedButton.icon(
                  key: const Key('tenant-share-docs'),
                  onPressed: widget.onDocs,
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(homiziText(context, 'View Documents')),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('tenant-chat-field'),
                    controller: _text,
                    decoration: InputDecoration(
                      hintText: homiziText(context, 'Type a message'),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('tenant-chat-send'),
                  onPressed: () {
                    widget.onSend(_text.text);
                    _text.clear();
                  },
                  icon: const Icon(Icons.send, color: HomiziColors.accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TenantContactPage extends StatelessWidget {
  const TenantContactPage({
    required this.pick,
    required this.sharingOn,
    required this.alreadyShared,
    required this.onBack,
    required this.onToggle,
    required this.onShare,
    super.key,
  });

  final TenantFlowPick pick;
  final bool sharingOn;
  final bool alreadyShared;
  final VoidCallback onBack;
  final ValueChanged<bool> onToggle;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-contact'),
      onBack: onBack,
      title: 'View Contact Details',
      bottom: TenantNextButton(
        label: alreadyShared ? 'Contact shared' : 'Share Contact',
        onPressed: sharingOn && !alreadyShared ? onShare : null,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            homiziText(context, pick.personName),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 20,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('tenant-share-setting'),
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Allow contact after a match')),
            value: sharingOn,
            onChanged: onToggle,
          ),
          Text(
            homiziText(
              context,
              sharingOn
                  ? 'Sharing is on. ${pick.personName} will see that you agreed. The phone number stays off this screen.'
                  : 'Contact stays hidden until you turn sharing on.',
            ),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontFamily: 'Inter',
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class TenantDocsPage extends StatelessWidget {
  const TenantDocsPage({
    required this.shared,
    required this.onBack,
    required this.onShare,
    super.key,
  });

  final bool shared;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-docs'),
      onBack: onBack,
      title: 'Documents',
      bottom: TenantNextButton(
        label: shared ? 'Documents shared' : 'Share Documents',
        onPressed: shared ? null : onShare,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.folder_outlined, size: 48, color: HomiziColors.ink),
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              shared
                  ? 'The documents flag is on for this match. No file was uploaded.'
                  : 'Share that your documents are ready. No file is uploaded from this screen.',
            ),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontFamily: 'Inter',
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class TenantVisitPage extends StatelessWidget {
  const TenantVisitPage({
    required this.pick,
    required this.onBack,
    required this.onBook,
    super.key,
  });

  final TenantFlowPick pick;
  final VoidCallback onBack;
  final ValueChanged<String> onBook;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-visit'),
      onBack: onBack,
      title: 'Book a Visit',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            homiziText(context, pick.title),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'Pick a time. The visit is a slot, not a street address.',
            ),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 12),
          for (final slot in visitSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: Key('tenant-slot-$slot'),
                onPressed: () => onBook(slot),
                child: Text(homiziText(context, slot)),
              ),
            ),
        ],
      ),
    );
  }
}

class TenantBookedPage extends StatelessWidget {
  const TenantBookedPage({
    required this.pick,
    required this.slot,
    required this.onBack,
    super.key,
  });

  final TenantFlowPick pick;
  final String slot;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return TenantFlowScaffold(
      pageKey: const Key('tenant-flow-booked'),
      onBack: onBack,
      title: 'Visit booked',
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(
            Icons.event_available,
            size: 64,
            color: HomiziColors.success,
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(context, 'Visit booked'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, '${pick.title} with ${pick.personName}'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
              fontFamily: 'PlusJakartaSans',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, slot),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'The visit time is saved for this match. It is a time slot, not a street address.',
            ),
            style: const TextStyle(
              color: HomiziColors.inkSoft,
              fontFamily: 'Inter',
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
