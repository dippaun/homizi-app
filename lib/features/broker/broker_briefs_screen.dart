import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_page.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roles/seeker_match.dart';
import 'package:homizi/features/roles/seeker_providers.dart';

class BrokerBriefsScreen extends ConsumerStatefulWidget {
  const BrokerBriefsScreen({super.key});

  @override
  ConsumerState<BrokerBriefsScreen> createState() => _BrokerBriefsScreenState();
}

class _BrokerBriefsScreenState extends ConsumerState<BrokerBriefsScreen> {
  SeekerMatchPage? _page;
  String? _error;
  var _loading = true;

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
      setState(() {
        _page = page;
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

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      key: const Key('broker-briefs-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Requirement briefs'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  homiziText(
                    context,
                    page?.basis ??
                        'Briefs from people who opted in. Phone numbers stay hidden.',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  homiziText(
                    context,
                    'Contact stays hidden until you both match and they share it.',
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Text(
                    homiziText(context, _error!),
                    key: const Key('broker-briefs-error'),
                  ),
                if (page == null || page.seekers.isEmpty)
                  Text(
                    homiziText(
                      context,
                      'No discoverable briefs match your listings yet.',
                    ),
                    key: const Key('broker-briefs-empty'),
                  ),
                for (final seeker in page?.seekers ?? const <SeekerMatch>[])
                  BrokerTapCard(
                    cardKey: Key('broker-brief-card-${seeker.requirementId}'),
                    onTap: () => context.push(
                      RoutePaths.brokerBrief(seeker.requirementId),
                    ),
                    child: _BriefSummary(seeker: seeker),
                  ),
                OutlinedButton(
                  key: const Key('broker-briefs-listings'),
                  onPressed: () => context.go(RoutePaths.listings),
                  child: Text(homiziText(context, 'Manage listings')),
                ),
              ],
            ),
    );
  }
}

class BrokerBriefScreen extends ConsumerStatefulWidget {
  const BrokerBriefScreen({required this.requirementId, super.key});

  final String requirementId;

  @override
  ConsumerState<BrokerBriefScreen> createState() => _BrokerBriefScreenState();
}

class _BrokerBriefScreenState extends ConsumerState<BrokerBriefScreen> {
  SeekerMatch? _seeker;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final page = await ref.read(seekerMatchGatewayProvider).load();
      SeekerMatch? match;
      for (final seeker in page.seekers) {
        if (seeker.requirementId == widget.requirementId) {
          match = seeker;
          break;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _seeker = match;
        _loading = false;
        if (match == null) {
          _error = 'This brief is not available.';
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'The seeker list could not be loaded.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final seeker = _seeker;
    if (_loading) {
      return const Scaffold(
        key: Key('broker-brief-screen'),
        backgroundColor: HomiziColors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (seeker == null) {
      return BrokerPage(
        screenKey: const Key('broker-brief-screen'),
        title: 'Requirement brief',
        children: [
          Text(homiziText(context, _error ?? 'This brief is not available.')),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('broker-brief-home'),
            onPressed: () => context.go(RoutePaths.home),
            child: Text(homiziText(context, 'Broker home')),
          ),
        ],
      );
    }
    return BrokerPage(
      screenKey: const Key('broker-brief-screen'),
      title: 'Requirement brief',
      children: [
        _BriefSummary(seeker: seeker),
        if (seeker.aboutMe.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(homiziText(context, seeker.aboutMe)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('broker-brief-chat'),
          onPressed: () => context.push(
            RoutePaths.chat(
              'broker-${seeker.requirementId}',
              name: seeker.displayName,
              title: 'Requirement brief',
            ),
          ),
          child: Text(homiziText(context, 'Open chat')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('broker-brief-visit'),
          onPressed: () => context.push(
            Uri(
              path: RoutePaths.brokerVisits,
              queryParameters: {'seeker': seeker.displayName},
            ).toString(),
          ),
          child: Text(homiziText(context, 'Schedule a visit')),
        ),
      ],
    );
  }
}

class _BriefSummary extends StatelessWidget {
  const _BriefSummary({required this.seeker});

  final SeekerMatch seeker;

  @override
  Widget build(BuildContext context) {
    final kind = seeker.seekerKind == 'roommate' ? 'Flatmate' : 'Tenant';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, seeker.displayName),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          homiziText(
            context,
            '$kind · ${seeker.city} · ${seeker.localities.join(', ')}',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            '${formatInr(seeker.budgetMinInr)} – ${formatInr(seeker.budgetMaxInr)} · ${seeker.matchPercent}% match',
          ),
        ),
        if (seeker.roomType.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            homiziText(
              context,
              joinRequirementLabels(
                seeker.roomType.split(','),
                requirementRoomTypeLabel,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
