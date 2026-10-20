import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_leads_sheet.dart';
import 'package:homizi/features/owner/owner_models.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/owner/owner_rules.dart';
import 'package:homizi/features/trust/trust_badge_section.dart';

final ownerListingsProvider = FutureProvider.autoDispose<List<OwnerListing>>((
  ref,
) {
  return ref.watch(ownerGatewayProvider).myListings();
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(ownerListingsProvider);
    return Scaffold(
      key: const Key('owner-dashboard'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'My listings')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('owner-new-listing'),
        onPressed: () => context.push('${RoutePaths.listingEditor}?fresh=1'),
        icon: const Icon(Icons.add_home_outlined),
        label: Text(homiziText(context, 'List your home free')),
      ),
      body: listings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _DashboardMessage(
          title: 'Listings did not load',
          body: error is OwnerFailure
              ? error.message
              : 'Retry to read your listings.',
          action: 'Try again',
          onAction: () => ref.invalidate(ownerListingsProvider),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return _DashboardMessage(
              title: 'No listings yet',
              body:
                  'List your home free. A draft stays private until you publish.',
              action: 'Start a listing',
              onAction: () =>
                  context.push('${RoutePaths.listingEditor}?fresh=1'),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              const TrustBadgeSection(),
              const SizedBox(height: 16),
              for (final listing in rows) ...[
                _OwnerListingCard(listing: listing),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              homiziText(context, title),
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(homiziText(context, body), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              child: Text(homiziText(context, action)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerListingCard extends ConsumerStatefulWidget {
  const _OwnerListingCard({required this.listing});

  final OwnerListing listing;

  @override
  ConsumerState<_OwnerListingCard> createState() => _OwnerListingCardState();
}

class _OwnerListingCardState extends ConsumerState<_OwnerListingCard> {
  var _busy = false;

  Future<void> _act(String action) async {
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Listing posted',
        detail: 'The home status is saved for this demo.',
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final message = await ref
          .read(ownerGatewayProvider)
          .act(widget.listing.id, action);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(homiziText(context, message))));
      ref.invalidate(ownerListingsProvider);
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showTenants() async {
    setState(() => _busy = true);
    try {
      final people = await ref
          .read(ownerGatewayProvider)
          .interestedTenants(widget.listing.id);
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.4,
            builder: (context, controller) {
              return _InterestedTenantsSheet(
                people: people,
                controller: controller,
              );
            },
          );
        },
      );
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showLeads() async {
    setState(() => _busy = true);
    try {
      final leads = await ref
          .read(ownerGatewayProvider)
          .leads(widget.listing.id);
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: HomiziColors.white,
        builder: (sheetContext) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.4,
            builder: (context, controller) {
              return OwnerLeadsSheet(leads: leads, controller: controller);
            },
          );
        },
      );
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(homiziText(context, error.message))),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final scheme = Theme.of(context).colorScheme;
    return Card.outlined(
      key: Key('owner-listing-${listing.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    homiziText(context, listing.title),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _StatusChip(chip: listing.chip),
              ],
            ),
            const SizedBox(height: 4),
            Text(homiziText(context, listing.place)),
            const SizedBox(height: 4),
            Text(
              homiziText(context, '${formatInr(listing.rentInr)}/mo'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Count(label: '${listing.views} views'),
                _Count(label: '${listing.saves} saves'),
                _Count(label: '${listing.interests} interests'),
                _Count(label: '${listing.visitRequests} visit requests'),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canEditListing(listing.status))
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => context.push(
                            '${RoutePaths.listingEditor}?id=${listing.id}',
                          ),
                    child: Text(homiziText(context, 'Edit')),
                  ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => context.push(RoutePaths.listingStats(listing.id)),
                  child: Text(homiziText(context, 'Stats')),
                ),
                OutlinedButton(
                  key: Key('interested-${listing.id}'),
                  onPressed: _busy ? null : () => unawaited(_showTenants()),
                  child: Text(homiziText(context, 'Interested tenants')),
                ),
                OutlinedButton(
                  key: Key('leads-${listing.id}'),
                  onPressed: _busy ? null : () => unawaited(_showLeads()),
                  child: Text(homiziText(context, 'Leads')),
                ),
                OutlinedButton(
                  key: Key('photos-${listing.id}'),
                  onPressed: _busy
                      ? null
                      : () => context.push(RoutePaths.photoManager),
                  child: Text(homiziText(context, 'Photos')),
                ),
                OutlinedButton(
                  key: Key('visits-${listing.id}'),
                  onPressed: _busy
                      ? null
                      : () => context.push(RoutePaths.hostVisits),
                  child: Text(homiziText(context, 'Visits')),
                ),
                if (canPauseListing(listing.status))
                  OutlinedButton(
                    key: Key('pause-${listing.id}'),
                    onPressed: _busy ? null : () => unawaited(_act('pause')),
                    child: Text(homiziText(context, 'Pause')),
                  ),
                if (canResumeListing(listing.status))
                  OutlinedButton(
                    key: Key('resume-${listing.id}'),
                    onPressed: _busy ? null : () => unawaited(_act('resume')),
                    child: Text(homiziText(context, 'Resume')),
                  ),
                if (canMarkRented(listing.status))
                  OutlinedButton(
                    key: Key('rented-${listing.id}'),
                    onPressed: _busy
                        ? null
                        : () => unawaited(_act('mark_rented')),
                    child: Text(homiziText(context, 'Mark rented')),
                  ),
                if (canRenewListing(listing.status))
                  OutlinedButton(
                    key: Key('renew-${listing.id}'),
                    onPressed: _busy ? null : () => unawaited(_act('renew')),
                    child: Text(homiziText(context, 'Renew')),
                  ),
                if (canDeleteDraft(listing.status))
                  TextButton(
                    key: Key('delete-draft-${listing.id}'),
                    onPressed: _busy
                        ? null
                        : () => unawaited(_act('delete_draft')),
                    child: Text(
                      homiziText(context, 'Delete draft'),
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestedTenantsSheet extends StatefulWidget {
  const _InterestedTenantsSheet({
    required this.people,
    required this.controller,
  });

  final List<InterestedTenant> people;
  final ScrollController controller;

  @override
  State<_InterestedTenantsSheet> createState() =>
      _InterestedTenantsSheetState();
}

class _InterestedTenantsSheetState extends State<_InterestedTenantsSheet> {
  int _min = InrRangeScale.min;
  int _max = InrRangeScale.max;

  @override
  Widget build(BuildContext context) {
    final open = openBounds(
      start: _min,
      end: _max,
      min: InrRangeScale.min,
      max: InrRangeScale.max,
    );
    final visible = [
      for (final person in widget.people)
        if (budgetOverlaps(
          min: person.budgetMinInr,
          max: person.budgetMaxInr,
          filterMin: open.start,
          filterMax: open.end,
        ))
          person,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                homiziText(context, 'Interested tenants'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              HomiziRangeField(
                label: 'Tenant budget',
                min: InrRangeScale.min,
                max: InrRangeScale.max,
                step: InrRangeScale.step,
                start: _min,
                end: _max,
                formatValue: formatInr,
                openAtBounds: true,
                minSemantics: 'Budget minimum (INR)',
                maxSemantics: 'Budget maximum (INR)',
                sliderKey: const Key('owner-tenant-budget-slider'),
                valueKey: const Key('owner-tenant-budget-value'),
                onChanged: (start, end) => setState(() {
                  _min = start;
                  _max = end;
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              if (widget.people.isEmpty)
                Text(homiziText(context, 'No interested tenants yet.'))
              else if (visible.isEmpty)
                Text(homiziText(context, 'No tenants in this budget.'))
              else
                for (final person in visible) ...[
                  const SizedBox(height: 12),
                  _InterestedTenantTile(person: person),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InterestedTenantTile extends StatelessWidget {
  const _InterestedTenantTile({required this.person});

  final InterestedTenant person;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final budget = person.budgetMinInr != null && person.budgetMaxInr != null
        ? '${formatInr(person.budgetMinInr!)}–${formatInr(person.budgetMaxInr!)}'
        : null;
    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HostAvatar(
                  name: person.displayName,
                  photoRef: person.avatarUrl,
                  radius: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, person.displayName),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (person.occupation.isNotEmpty)
                        Text(homiziText(context, person.occupation)),
                      if (person.ageRange != null &&
                          person.ageRange!.isNotEmpty)
                        Text(
                          homiziText(context, person.ageRange!),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (budget != null) ...[
              const SizedBox(height: 8),
              Text(homiziText(context, budget)),
            ],
            if (person.moveInIso != null && person.moveInIso!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(homiziText(context, 'Move-in ${person.moveInIso}')),
            ],
            if (person.about.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(homiziText(context, person.about)),
            ],
            if (person.lifestyle.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in person.lifestyle)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(homiziText(context, tag)),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      visualDensity: VisualDensity.compact,
      label: Text(homiziText(context, label)),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.chip});

  final String chip;

  @override
  Widget build(BuildContext context) {
    final live = chip == 'live';
    return Chip(
      key: Key('status-$chip'),
      visualDensity: VisualDensity.compact,
      label: Text(homiziText(context, ownerChipLabel(chip))),
      backgroundColor: live ? HomiziColors.accentWash : HomiziColors.mist,
      side: BorderSide(color: live ? HomiziColors.accent : HomiziColors.line),
    );
  }
}
