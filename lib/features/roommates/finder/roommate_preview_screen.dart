import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/roommates/finder/finder_catalog.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/finder_widgets.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';
import 'package:homizi/features/shell/min_touch.dart';

class RoommatePreviewScreen extends ConsumerStatefulWidget {
  const RoommatePreviewScreen({required this.personId, super.key});

  final String personId;

  @override
  ConsumerState<RoommatePreviewScreen> createState() =>
      _RoommatePreviewScreenState();
}

class _RoommatePreviewScreenState extends ConsumerState<RoommatePreviewScreen> {
  var _photo = 0;

  @override
  Widget build(BuildContext context) {
    final person = finderPersonById(widget.personId);
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
    final score = scoreFinderPerson(snapshot.requirements, person);
    final theme = Theme.of(context);
    final photos = person.gallery;
    final safeIndex = photos.isEmpty ? 0 : _photo.clamp(0, photos.length - 1);
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
                      Stack(
                        children: [
                          Hero(
                            tag: 'roommate-photo-${person.id}',
                            child: SizedBox(
                              height: 320,
                              width: double.infinity,
                              child: photos.isEmpty
                                  ? const ColoredBox(color: HomiziColors.soft)
                                  : Image.asset(
                                      photos[safeIndex],
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const Positioned(
                            left: 4,
                            top: 36,
                            child: HomiziBackButton(),
                          ),
                          Positioned(
                            right: 4,
                            top: 36,
                            child: Row(
                              children: [
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
                          if (photos.isNotEmpty)
                            Positioned(
                              right: 16,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: HomiziColors.ink.withValues(
                                    alpha: 0.72,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '${safeIndex + 1}/${photos.length}',
                                  style: const TextStyle(
                                    color: HomiziColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (photos.length > 1)
                        SizedBox(
                          height: 64,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            itemCount: photos.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return InkWell(
                                key: Key('roommate-thumb-$index'),
                                onTap: () => setState(() => _photo = index),
                                child: Container(
                                  width: 72,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: index == safeIndex
                                          ? HomiziColors.logoOrange
                                          : HomiziColors.line,
                                      width: 2,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.asset(
                                    photos[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    person.name,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: HomiziColors.ink,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                if (person.seeker.trust.anyIdentity)
                                  const Icon(
                                    Icons.verified,
                                    color: HomiziColors.success,
                                  ),
                              ],
                            ),
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
                                      ? homiziText(context, 'Score unavailable')
                                      : '${score.percent}% Match',
                                  style: const TextStyle(
                                    color: HomiziColors.success,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _pill(
                                  Icons.currency_rupee,
                                  '${formatInr(person.traits.budgetMinInr ?? 0)} – ${formatInr(person.traits.budgetMaxInr ?? 0)}',
                                ),
                                _pill(
                                  Icons.home_outlined,
                                  'Looking for ${person.lookingFor}',
                                ),
                                _pill(
                                  Icons.event,
                                  finderMoveInLabel(person.traits.moveIn),
                                ),
                                _pill(
                                  Icons.person_outline,
                                  finderGenderLabel(person.traits.gender),
                                ),
                              ],
                            ),
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
                            const SizedBox(height: 18),
                            Text(
                              homiziText(context, 'More About Me'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: HomiziColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _fact('Education', person.education),
                            _fact('Hometown', person.hometown),
                            _fact(
                              'Languages',
                              person.traits.languages.join(', '),
                            ),
                            _fact(
                              'Active on Homizi',
                              person.online ? 'Online now' : 'Recently active',
                            ),
                            const SizedBox(height: 18),
                            _breakdown(score),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
    return Container(
      width: 104,
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
    );
  }

  Widget _fact(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: HomiziColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakdown(FinderScore score) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomiziColors.soft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CompatibilityRing(percent: score.percent, size: 88),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                for (final part in score.parts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          part.ok ? Icons.check_circle : Icons.circle_outlined,
                          size: 18,
                          color: part.ok
                              ? HomiziColors.success
                              : HomiziColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            part.percent == null
                                ? part.label
                                : '${part.label} · ${part.percent}%',
                            style: const TextStyle(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
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
