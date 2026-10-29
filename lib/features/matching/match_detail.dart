import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_catalog.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/matching/match_flow.dart';
import 'package:homizi/features/matching/match_widgets.dart';

class MatchExplainedScreen extends ConsumerWidget {
  const MatchExplainedScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(matchControllerProvider);
    final card = ref.read(matchControllerProvider.notifier).card(id);
    if (card == null) {
      return const MatchScaffold(
        title: 'Match Score Explained',
        body: Center(child: Text('This match is not in the demo.')),
      );
    }
    final breakdown = card.breakdown;
    return MatchScaffold(
      title: 'Match Score Explained',
      body: ListView(
        key: const Key('match-explained'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            homiziText(context, card.title),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          MatchPill(breakdown: breakdown),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (breakdown.verified) const VerifyBadge(label: 'Verified'),
              if (breakdown.listingVerified)
                const VerifyBadge(label: 'Verified listing'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'Verification is not added into the compatibility score.',
            ),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          const SizedBox(height: 16),
          Text(
            homiziText(context, breakdown.headline),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 12),
          _Lines(
            title: 'Why this is a great match (Top 5)',
            lines: breakdown.topReasons,
          ),
          _Lines(title: 'Some differences', lines: breakdown.differences),
          _Lines(title: 'Not a good match because', lines: breakdown.blockers),
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Key match factors'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          for (final factor in breakdown.factors)
            FactorBar(label: factor.label, percent: factor.barPercent),
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Other boosters'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete photos, a recent listing, and a high rating only break a tie. They are not added into the percent, so a new listing is not buried.',
          ),
          for (final booster in breakdown.boosters)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(homiziText(context, booster.label)),
              subtitle: Text(homiziText(context, booster.detail)),
              trailing: Text('+${booster.points}'),
            ),
          Text(
            homiziText(
              context,
              'Total compatibility score = ${breakdown.score}%',
            ),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (card.roomiePercent != null) ...[
            const SizedBox(height: 16),
            Text(
              homiziText(
                context,
                'Roomie Compatibility Score ${card.roomiePercent}%',
              ),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            const Text(
              'Budget, location, smoking, drinking, food, cleanliness, sleep schedule, guests, and cooking. This number is separate from the property score.',
            ),
          ],
          if (session.signals.weights.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Likes, skips, and saves have nudged the ranking slightly. Reset learned signals on the priorities page.',
              ),
            ),
        ],
      ),
    );
  }
}

class _Lines extends StatelessWidget {
  const _Lines({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, title),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (lines.isEmpty)
            Text(homiziText(context, 'None'))
          else
            for (final line in lines) Text('• ${homiziText(context, line)}'),
        ],
      ),
    );
  }
}

class MatchCardScreen extends ConsumerWidget {
  const MatchCardScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(matchControllerProvider.notifier).card(id);
    if (card == null) {
      return const MatchScaffold(title: 'Listing', body: SizedBox.shrink());
    }
    final saved = ref.watch(matchControllerProvider).saved.contains(id);
    return MatchScaffold(
      title: 'Detailed View',
      body: ListView(
        key: const Key('match-detail'),
        padding: const EdgeInsets.all(16),
        children: [
          if (card.photoAssets.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                card.photoAssets.first,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    const SizedBox(height: 200),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              card.photoAssets.isEmpty
                  ? 'No listing photo'
                  : '1/${card.photoAssets.length} Room (Main Photo)',
            ),
            style: const TextStyle(color: HomiziColors.muted),
          ),
          const SizedBox(height: 12),
          MatchPill(breakdown: card.breakdown),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              if (card.breakdown.verified)
                const VerifyBadge(label: 'Verified Host'),
              if (card.breakdown.listingVerified)
                const VerifyBadge(label: 'Verified Listing'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, card.title),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          Text(
            homiziText(context, '${card.place} · ${card.priceLabel}'),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'Key details'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          Text(homiziText(context, card.keyDetails)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final chip in card.chips)
                Chip(label: Text(homiziText(context, chip))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Why this is a great match (Top 5)'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          for (final line in card.breakdown.topReasons)
            Text('• ${homiziText(context, line)}'),
          const SizedBox(height: 12),
          Text(
            homiziText(context, card.personName),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          Text(homiziText(context, '${card.personRole} · ${card.replyLabel}')),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Nearby places'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          for (final place in card.nearby) Text(homiziText(context, place)),
          const SizedBox(height: 8),
          Text(
            homiziText(context, card.commuteLabel),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          TextButton(
            onPressed: () => context.push(RoutePaths.matchCommuteFor(id)),
            child: Text(homiziText(context, 'See commute on map')),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(matchControllerProvider.notifier).skip(id);
                    context.pop();
                  },
                  child: Text(homiziText(context, 'Skip')),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  key: const Key('match-detail-like'),
                  onPressed: () {
                    final mutual = ref
                        .read(matchControllerProvider.notifier)
                        .like(id);
                    if (mutual) {
                      context.push(RoutePaths.matchMutual(id));
                    } else if (context.mounted) {
                      context.pop();
                    }
                  },
                  child: Text(homiziText(context, "I'm Interested")),
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: () =>
                ref.read(matchControllerProvider.notifier).toggleSave(id),
            child: Text(
              homiziText(context, saved ? 'Saved' : 'Save / Shortlist'),
            ),
          ),
        ],
      ),
    );
  }
}

class ItsAMatchScreen extends ConsumerWidget {
  const ItsAMatchScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(matchControllerProvider.notifier).card(id);
    final name = card?.personName ?? 'them';
    return MatchScaffold(
      title: "It's a Match",
      body: ListView(
        key: const Key('match-mutual'),
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.favorite, color: HomiziColors.accent, size: 56),
          const SizedBox(height: 12),
          Text(
            homiziText(context, "It's a Match!"),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, 'You and $name are interested in each other.'),
            style: const TextStyle(color: HomiziColors.ink, fontSize: 16),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('match-start-chat'),
            onPressed: () => context.push(RoutePaths.matchChat(id)),
            child: Text(homiziText(context, 'Start Chat')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('match-view-contact'),
            onPressed: () => context.push(RoutePaths.matchContact(id)),
            child: Text(homiziText(context, 'View Contact Details')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('match-book-visit'),
            onPressed: () => context.push(RoutePaths.matchVisit(id)),
            child: Text(homiziText(context, 'Book a Visit')),
          ),
        ],
      ),
    );
  }
}

class MatchChatScreen extends ConsumerStatefulWidget {
  const MatchChatScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<MatchChatScreen> createState() => _MatchChatScreenState();
}

class _MatchChatScreenState extends ConsumerState<MatchChatScreen> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref
        .watch(matchControllerProvider.notifier)
        .messagesFor(widget.id);
    ref.watch(matchControllerProvider);
    return MatchScaffold(
      title: 'Chat',
      body: Column(
        children: [
          Expanded(
            child: ListView(
              key: const Key('match-chat-list'),
              padding: const EdgeInsets.all(16),
              children: [
                for (final message in messages)
                  Align(
                    alignment: message.fromSelf
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.fromSelf
                            ? HomiziColors.accentWash
                            : HomiziColors.mist,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        homiziText(context, message.body),
                        style: const TextStyle(color: HomiziColors.ink),
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
              children: [
                OutlinedButton(
                  key: const Key('match-share-contact'),
                  onPressed: () =>
                      context.push(RoutePaths.matchContact(widget.id)),
                  child: Text(homiziText(context, 'Share Contact')),
                ),
                OutlinedButton(
                  key: const Key('match-schedule-visit'),
                  onPressed: () =>
                      context.push(RoutePaths.matchVisit(widget.id)),
                  child: Text(homiziText(context, 'Schedule Visit')),
                ),
                OutlinedButton(
                  key: const Key('match-share-docs'),
                  onPressed: () =>
                      context.push(RoutePaths.matchDocs(widget.id)),
                  child: Text(homiziText(context, 'Share Documents')),
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
                    key: const Key('match-chat-field'),
                    controller: _text,
                    decoration: InputDecoration(
                      hintText: homiziText(context, 'Type a message'),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('match-chat-send'),
                  onPressed: () {
                    ref
                        .read(matchControllerProvider.notifier)
                        .send(widget.id, _text.text);
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

class MatchVisitScreen extends ConsumerWidget {
  const MatchVisitScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MatchScaffold(
      title: 'Book a Visit',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pick a time. The visit is a slot, not a street address.',
            style: TextStyle(color: HomiziColors.ink),
          ),
          const SizedBox(height: 12),
          for (final slot in visitSlots)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                key: Key('match-slot-${slot.hashCode}'),
                onPressed: () {
                  ref
                      .read(matchControllerProvider.notifier)
                      .bookVisit(id, slot);
                  context.push(RoutePaths.matchVisitDone(id));
                },
                child: Text(homiziText(context, slot)),
              ),
            ),
        ],
      ),
    );
  }
}

class MatchContactScreen extends ConsumerStatefulWidget {
  const MatchContactScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<MatchContactScreen> createState() => _MatchContactScreenState();
}

class _MatchContactScreenState extends ConsumerState<MatchContactScreen> {
  var _agreed = false;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(matchControllerProvider);
    final card = ref.read(matchControllerProvider.notifier).card(widget.id);
    final name = card?.personName ?? 'this match';
    return MatchScaffold(
      title: 'View Contact Details',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            key: const Key('match-share-setting'),
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Allow contact after a match')),
            value: session.shareContact,
            onChanged: (value) {
              ref.read(matchControllerProvider.notifier).setShareContact(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            session.shareContact
                ? homiziText(
                    context,
                    'Sharing is on. $name will see that you agreed. The phone number stays off this screen.',
                  )
                : homiziText(
                    context,
                    'Contact stays hidden until you turn sharing on.',
                  ),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            key: const Key('match-consent-check'),
            contentPadding: EdgeInsets.zero,
            value: _agreed,
            onChanged: session.shareContact
                ? (value) => setState(() => _agreed = value ?? false)
                : null,
            title: Text(
              homiziText(context, 'I agree to share contact for this match'),
            ),
          ),
          FilledButton(
            key: const Key('match-consent-confirm'),
            onPressed: session.shareContact && _agreed
                ? () {
                    ref
                        .read(matchControllerProvider.notifier)
                        .shareContactWith(widget.id);
                    context.push(RoutePaths.matchContactDone(widget.id));
                  }
                : null,
            child: Text(homiziText(context, 'Share Contact')),
          ),
        ],
      ),
    );
  }
}

class MatchDocsScreen extends ConsumerWidget {
  const MatchDocsScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MatchScaffold(
      title: 'Share Documents',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Employment letter and a verified badge. No file leaves this demo.',
            style: TextStyle(color: HomiziColors.ink),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('match-docs-confirm'),
            onPressed: () {
              ref.read(matchControllerProvider.notifier).shareDocumentsWith(id);
              context.push(RoutePaths.matchDocsDone(id));
            },
            child: Text(homiziText(context, 'Share Documents')),
          ),
        ],
      ),
    );
  }
}

class MatchCommuteScreen extends ConsumerWidget {
  const MatchCommuteScreen({this.homeId, super.key});

  final String? homeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(matchControllerProvider);
    final home =
        demoHomeById(homeId ?? 'lst_match_bandra') ?? demoMatchHomes.first;
    final minutes = commuteMinutesFor(
      locality: home.locality,
      latitude: home.approxLatitude,
      longitude: home.approxLongitude,
      commute: session.commute,
    );
    final notifier = ref.read(matchControllerProvider.notifier);
    return MatchScaffold(
      title: 'Live Closer to What Matters',
      body: ListView(
        key: const Key('match-commute'),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            homiziText(context, 'Shorter commute, happier life.'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              '${home.title} · ${home.locality} to ${session.activeOffice.label}',
            ),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: CustomPaint(
              painter: _CommuteMapPainter(),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, formatCommute(minutes)),
            key: const Key('match-commute-minutes'),
            style: const TextStyle(
              color: HomiziColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final mode in TransportMode.values)
                ChoiceChip(
                  key: Key('match-mode-${mode.name}'),
                  label: Text(homiziText(context, transportModeLabel(mode))),
                  selected: session.mode == mode,
                  onSelected: (_) => notifier.setMode(mode),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Max commute'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final minutesChoice in commuteMinuteChoices)
                ChoiceChip(
                  key: Key('match-max-$minutesChoice'),
                  label: Text(homiziText(context, '$minutesChoice min')),
                  selected: session.maxMinutes == minutesChoice,
                  onSelected: (_) => notifier.setMaxMinutes(minutesChoice),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Offices'),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          for (final office in session.offices)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(homiziText(context, office.label)),
              trailing: session.activeOfficeId == office.id
                  ? const Icon(Icons.check, color: HomiziColors.accent)
                  : null,
              onTap: () => notifier.setActiveOffice(office.id),
            ),
          for (final office in presetOffices)
            if (!session.offices.any((item) => item.id == office.id))
              OutlinedButton(
                key: Key('match-add-office-${office.id}'),
                onPressed: () => notifier.addOffice(office.id),
                child: Text(homiziText(context, 'Add ${office.label}')),
              ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('match-set-commute-priority'),
            onPressed: () {
              notifier.prioritizeCommute();
              context.push(RoutePaths.matchCommuteSaved);
            },
            child: Text(
              homiziText(context, 'Set Commute to Office as priority 1'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommuteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()..color = HomiziColors.mist;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      road,
    );
    final line = Paint()
      ..color = HomiziColors.accent
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    final start = Offset(size.width * 0.25, size.height * 0.7);
    final end = Offset(size.width * 0.75, size.height * 0.3);
    canvas.drawLine(start, end, line);
    canvas.drawCircle(start, 10, Paint()..color = HomiziColors.ink);
    canvas.drawCircle(end, 10, Paint()..color = HomiziColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ResetSignalsScreen extends ConsumerStatefulWidget {
  const ResetSignalsScreen({super.key});

  @override
  ConsumerState<ResetSignalsScreen> createState() => _ResetSignalsScreenState();
}

class _ResetSignalsScreenState extends ConsumerState<ResetSignalsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(matchControllerProvider.notifier).resetSignals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const MatchConfirmScreen(
      title: 'Learned signals reset',
      detail:
          'Likes, skips, and saves no longer nudge your ranking. You can edit priorities any time.',
      nextLabel: 'Back to priorities',
      nextPath: RoutePaths.matchPriorities,
    );
  }
}
