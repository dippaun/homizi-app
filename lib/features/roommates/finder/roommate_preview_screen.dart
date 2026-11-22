import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/match_score.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/homizi_portrait.dart';
import 'package:homizi/features/discovery/match_breakdown_sheet.dart';
import 'package:homizi/features/matching/match_engine.dart';
import 'package:homizi/features/matching/match_inputs.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/finder_widgets.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/shell/min_touch.dart';

class RoommatePreviewScreen extends ConsumerStatefulWidget {
  const RoommatePreviewScreen({
    required this.personId,
    this.reviewOnly = false,
    super.key,
  });

  final String personId;

  /// Opened from Roommate Matches. The person is already saved, so the
  /// Skip / Maybe / Interested bar stays off.
  final bool reviewOnly;

  @override
  ConsumerState<RoommatePreviewScreen> createState() =>
      _RoommatePreviewScreenState();
}

class _RoommatePreviewScreenState extends ConsumerState<RoommatePreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final person = _loadedPerson(ref, widget.personId);
    if (person == null) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          backgroundColor: HomiziColors.white,
        ),
        body: const EmptyState(
          title: 'Roommate not found',
          message: 'This profile is no longer on the deck.',
        ),
      );
    }
    final snapshot = ref.watch(finderProvider);
    final score = scoreFinderPerson(
      snapshot.requirements,
      person,
      ask: snapshot.ask,
      saved: snapshot.requirementsSaved,
    );
    final theme = Theme.of(context);
    return MinTouchScope(
      child: Scaffold(
        key: const Key('roommate-preview'),
        backgroundColor: HomiziColors.white,
        body: RepaintBoundary(
          key: const Key('roommate-preview-shot'),
          child: Material(
            color: HomiziColors.white,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                          child: Row(
                            children: [
                              const HomiziBackButton(),
                              const Spacer(),
                              IconButton(
                                key: const Key('roommate-share'),
                                tooltip: homiziText(context, 'Share'),
                                style: IconButton.styleFrom(
                                  backgroundColor: HomiziColors.white,
                                ),
                                onPressed: () => _share(person),
                                icon: const Icon(
                                  Icons.share_outlined,
                                  color: HomiziColors.ink,
                                ),
                              ),
                              IconButton(
                                key: const Key('roommate-preview-heart'),
                                tooltip: homiziText(context, 'Maybe'),
                                style: IconButton.styleFrom(
                                  backgroundColor: HomiziColors.white,
                                ),
                                onPressed: () {
                                  ref
                                      .read(finderProvider.notifier)
                                      .markMaybe(person.id);
                                  unawaited(
                                    context.push(
                                      RoutePaths.roommateMaybe(person.id),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.favorite_border,
                                  color: HomiziColors.logoOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: HomiziPortrait(
                          photo: _portrait(person),
                          verified: person.seeker.trust.aadhaarVerified,
                          semanticLabel: person.name,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        person.name,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (person.seeker.age > 0)
                              Text(
                                '${person.seeker.age} · ${person.group}',
                                style: const TextStyle(
                                  color: HomiziColors.inkSoft,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.place,
                                  size: 16,
                                  color: HomiziColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${person.traits.localities.join(', ')}, ${person.traits.city}  ·  ${person.field}',
                                    style: const TextStyle(
                                      color: HomiziColors.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                key: const Key('roommate-preview-why'),
                                onTap: score.report == null
                                    ? null
                                    : () => showMatchBreakdown(
                                        context,
                                        match: listingMatchFromReport(
                                          score.report!,
                                        ),
                                      ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HomiziColors.successWash,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    score.percent == null
                                        ? homiziText(
                                            context,
                                            'Score unavailable',
                                          )
                                        : '${score.percent}% Match',
                                    style: const TextStyle(
                                      color: HomiziColors.success,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if ((person.traits.budgetMinInr ?? 0) > 0 ||
                                    (person.traits.budgetMaxInr ?? 0) > 0)
                                  _pill(
                                    Icons.currency_rupee,
                                    '${formatInr(person.traits.budgetMinInr ?? 0)} – ${formatInr(person.traits.budgetMaxInr ?? 0)}',
                                  ),
                                if (person.lookingFor.trim().isNotEmpty &&
                                    person.lookingFor != 'roommate')
                                  _pill(
                                    Icons.home_outlined,
                                    'Looking for ${person.lookingFor}',
                                  ),
                                if (person.traits.moveIn != null)
                                  _pill(
                                    Icons.event,
                                    finderMoveInLabel(person.traits.moveIn),
                                  ),
                                if ((person.traits.gender ?? '').isNotEmpty)
                                  _pill(
                                    Icons.person_outline,
                                    finderGenderLabel(person.traits.gender),
                                  ),
                                if (person.field.trim().isNotEmpty &&
                                    person.field != 'Roommate')
                                  _pill(Icons.work_outline, person.field),
                              ],
                            ),
                            if (person.about.trim().isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Text(
                                homiziText(
                                  context,
                                  'About ${person.name.split(' ').first}',
                                ),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: HomiziColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                person.about,
                                style: const TextStyle(
                                  color: HomiziColors.inkSoft,
                                  height: 1.4,
                                ),
                              ),
                            ],
                            if (finderHabitLabels(person).isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Text(
                                homiziText(context, 'Lifestyle & Preferences'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: HomiziColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final label in finderHabitLabels(person))
                                    _habit(label),
                                ],
                              ),
                            ],
                            if (person.traits.languages.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Text(
                                homiziText(context, 'Languages'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: HomiziColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(person.traits.languages.join(', ')),
                            ],
                            if (_placePhotos(person).isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Text(
                                homiziText(context, 'Their place'),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: HomiziColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 72,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _placePhotos(person).length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final ref = _placePhotos(person)[index];
                                    return ClipRRect(
                                      key: Key('roommate-place-$index'),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.asset(
                                        ref,
                                        width: 96,
                                        height: 72,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            _compatibility(score),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_alreadyActed(person.id))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: RoommateActionBar(
                      keyPrefix: 'roommate-preview',
                      interestedLabel: "I'm Interested",
                      onSkip: () {
                        ref.read(finderProvider.notifier).pass(person.id);
                        context.pop();
                      },
                      onMaybe: () {
                        ref.read(finderProvider.notifier).markMaybe(person.id);
                        unawaited(
                          context.push(RoutePaths.roommateMaybe(person.id)),
                        );
                      },
                      onInterested: () => unawaited(_interest(person)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _interest(FinderPerson person) async {
    await guardVerifiedAction(
      context,
      ref,
      action: () async {
        try {
          final message = await ref
              .read(roommateGatewayProvider)
              .like(person.seeker);
          if (!mounted) {
            return;
          }
          ref.read(finderProvider.notifier).markInterested(person.id);
          final mutual =
              person.seeker.likesYou ||
              message == DiscoveryCopy.demoLikeMatched ||
              message == DiscoveryCopy.serverMatched;
          if (mutual) {
            unawaited(context.push(RoutePaths.roommateMatch(person.id)));
            return;
          }
          unawaited(context.push(RoutePaths.roommateSent(person.id)));
        } on RoommateFailure catch (error) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(homiziText(context, error.message))),
          );
        }
      },
    );
  }

  bool _alreadyActed(String id) {
    if (widget.reviewOnly) {
      return true;
    }
    final snapshot = ref.read(finderProvider);
    return snapshot.interested.contains(id) ||
        snapshot.maybe.contains(id) ||
        snapshot.passed.contains(id);
  }

  Widget _compatibility(FinderScore score) {
    final forward = _uniqueFactors(score.report?.factors ?? const []);
    final back = _uniqueFactors(
      score.otherReport?.factors ?? const [],
      skip: {for (final factor in forward) factor.label.toLowerCase()},
    );
    if (score.percent == null && forward.isEmpty && back.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CompatibilityRing(percent: score.percent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                homiziText(context, finderHeadline(score.percent)),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        if (forward.isNotEmpty) ...[
          const SizedBox(height: 14),
          _fitLabel('How they fit what you want'),
          const SizedBox(height: 8),
          _fitIcons(forward),
        ],
        if (back.isNotEmpty) ...[
          const SizedBox(height: 14),
          _fitLabel('How you fit what they want'),
          const SizedBox(height: 8),
          _fitIcons(back),
        ],
      ],
    );
  }

  Widget _fitLabel(String text) {
    return Text(
      homiziText(context, text),
      style: const TextStyle(
        color: HomiziColors.ink,
        fontWeight: FontWeight.w800,
        fontSize: 14,
      ),
    );
  }

  Widget _fitIcons(List<MatchFactorScore> factors) {
    return SingleChildScrollView(
      key: const Key('roommate-fit-icons'),
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < factors.length; index++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 200 + index * 35),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset((1 - value) * 10, 0),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _FitIcon(factor: factors[index]),
              ),
            ),
        ],
      ),
    );
  }

  String _portrait(FinderPerson person) {
    return personPortrait(
      personId: person.id,
      photoRef: person.seeker.photoRef,
      gallery: person.gallery,
    );
  }

  List<String> _placePhotos(FinderPerson person) {
    final face = _portrait(person);
    return [
      for (final ref in person.gallery)
        if (ref != face && !ref.toLowerCase().contains('avatar')) ref,
    ];
  }

  void _share(FinderPerson person) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          key: const Key('roommate-share-dialog'),
          backgroundColor: HomiziColors.white,
          title: Text(
            homiziText(context, 'Share ${person.name}'),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          content: Text(
            homiziText(
              context,
              'This profile stays inside Homizi. Phone and email are not included.',
            ),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                homiziText(context, 'Close'),
                style: const TextStyle(color: HomiziColors.ink),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      height: 36,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: HomiziColors.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: HomiziColors.ink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _habit(String label) {
    return SizedBox(
      width: 104,
      height: 88,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: HomiziColors.soft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(_habitIcon(label), color: HomiziColors.success),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

FinderPerson? _loadedPerson(WidgetRef ref, String id) {
  for (final person in ref.watch(finderProvider).people) {
    if (person.id == id || person.seeker.id == id) {
      return person;
    }
  }
  return finderPersonById(id);
}

List<MatchFactorScore> _uniqueFactors(
  List<MatchFactorScore> factors, {
  Set<String> skip = const {},
}) {
  final seen = <String>{};
  final kept = <MatchFactorScore>[];
  for (final factor in factors) {
    if (factor.maxPoints <= 0) {
      continue;
    }
    final key = factor.label.trim().toLowerCase();
    if (key.isEmpty || skip.contains(key) || !seen.add(key)) {
      continue;
    }
    final detail = factor.detail.trim().toLowerCase();
    if (detail.isNotEmpty && !seen.add(detail)) {
      continue;
    }
    kept.add(factor);
  }
  return kept;
}

class _FitIcon extends StatelessWidget {
  const _FitIcon({required this.factor});

  final MatchFactorScore factor;

  @override
  Widget build(BuildContext context) {
    final missing = factor.gap != MatchGap.none;
    final (mark, color, wash) = missing
        ? (Icons.add_circle, HomiziColors.brandGolden, HomiziColors.warningWash)
        : factor.matched
        ? (Icons.check_circle, HomiziColors.success, HomiziColors.successWash)
        : (Icons.cancel, HomiziColors.logoOrange, const Color(0xFFFFF1E8));
    return Tooltip(
      message: factor.detail.isEmpty ? factor.label : factor.detail,
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: wash,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(iconForMatchLabel(factor.label), color: color),
              ),
            ),
            const SizedBox(height: 4),
            Icon(mark, color: color, size: 16),
            Text(
              homiziText(context, factor.label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData _habitIcon(String label) {
  if (label.contains('Veg')) {
    return Icons.eco_outlined;
  }
  if (label.contains('Smok')) {
    return Icons.smoke_free;
  }
  if (label.contains('Drink')) {
    return Icons.local_bar_outlined;
  }
  if (label.contains('Pet')) {
    return Icons.pets;
  }
  if (label.contains('Work')) {
    return Icons.laptop_mac;
  }
  return Icons.auto_awesome;
}
