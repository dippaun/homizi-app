import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roles/seeker_match.dart';
import 'package:homizi/features/roles/seeker_providers.dart';

class SeekerMatchesScreen extends ConsumerStatefulWidget {
  const SeekerMatchesScreen({
    required this.title,
    this.showBrokerBadge = false,
    super.key,
  });

  final String title;
  final bool showBrokerBadge;

  @override
  ConsumerState<SeekerMatchesScreen> createState() =>
      _SeekerMatchesScreenState();
}

class _SeekerMatchesScreenState extends ConsumerState<SeekerMatchesScreen> {
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
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: Text(homiziText(context, widget.title)),
        actions: [
          if (widget.showBrokerBadge)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: BrokerChip()),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(homiziText(context, _error!)))
          : ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(homiziText(context, page?.basis ?? '')),
                const SizedBox(height: 8),
                Text(
                  homiziText(
                    context,
                    'Contact stays hidden until you both match and they share it.',
                  ),
                ),
                const SizedBox(height: 16),
                if (page == null || page.seekers.isEmpty)
                  Text(
                    homiziText(
                      context,
                      'No discoverable briefs match your listings yet.',
                    ),
                    key: const Key('seekers-empty'),
                  ),
                for (final seeker in page?.seekers ?? const <SeekerMatch>[])
                  _SeekerCard(seeker: seeker),
              ],
            ),
    );
  }
}

class _SeekerCard extends StatelessWidget {
  const _SeekerCard({required this.seeker});

  final SeekerMatch seeker;

  @override
  Widget build(BuildContext context) {
    final kind = seeker.seekerKind == 'roommate' ? 'Roommate' : 'Tenant';
    return Card(
      key: Key('seeker-card-${seeker.requirementId}'),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    homiziText(context, seeker.displayName),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  homiziText(context, '${seeker.matchPercent}% match'),
                  key: Key('seeker-match-${seeker.requirementId}'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                '${formatInr(seeker.budgetMinInr)} – ${formatInr(seeker.budgetMaxInr)} · ${joinRequirementLabels(seeker.roomType.split(','), requirementRoomTypeLabel)} · ${_professionLabel(seeker.profession)}',
              ),
            ),
            if (seeker.aboutMe.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(homiziText(context, seeker.aboutMe)),
            ],
          ],
        ),
      ),
    );
  }
}

String _professionLabel(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return 'Working';
  }
  return joinRequirementLabels(trimmed.split(','), requirementProfessionLabel);
}
