import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/roommates/finder/roommate_qualities.dart';

/// Compact matched-roommate row, shared by the tab and the See All page.
class RoommateMatchRow extends StatelessWidget {
  const RoommateMatchRow({
    required this.person,
    required this.percent,
    required this.onOpen,
    required this.onInterested,
    required this.onDismiss,
    this.onMessage,
    super.key,
  });

  final FinderPerson person;
  final int? percent;
  final VoidCallback onOpen;
  final VoidCallback onInterested;
  final VoidCallback onDismiss;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final name = person.name.trim();
    final title = name.isEmpty
        ? '${person.seeker.age}'
        : '$name, ${person.seeker.age}';
    final place = person.seeker.localityLabel.trim();
    final field = person.field.trim();
    final subtitle = [
      if (field.isNotEmpty) field,
      if (place.isNotEmpty) place,
    ].join(' · ');
    return Dismissible(
      key: Key('roommate-suggestion-${person.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: const ColoredBox(
        color: HomiziColors.error,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.close, color: HomiziColors.white),
          ),
        ),
      ),
      child: Material(
        color: HomiziColors.white,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
            child: Row(
              children: [
                PersonPhoto(
                  name: person.name,
                  photoRef: personPortrait(
                    personId: person.id,
                    photoRef: person.seeker.photoRef,
                    gallery: person.gallery,
                  ),
                  diameter: 44,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, title),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          homiziText(context, subtitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HomiziColors.inkSoft,
                            fontSize: 12,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _MiniAction(
                            buttonKey: Key(
                              'roommate-suggestion-interested-${person.id}',
                            ),
                            label: 'Interested',
                            onPressed: onInterested,
                          ),
                          if (onMessage != null) ...[
                            const SizedBox(width: 6),
                            _MiniAction(
                              buttonKey: Key(
                                'roommate-suggestion-message-${person.id}',
                              ),
                              label: 'Message',
                              onPressed: onMessage!,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (percent != null)
                        Container(
                          key: Key('roommate-suggestion-score-${person.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: HomiziColors.successWash,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$percent%',
                            style: const TextStyle(
                              color: HomiziColors.success,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 18),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 18,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: RoommateQualityIcons(person: person),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: Key('roommate-dismiss-${person.id}'),
                  tooltip: homiziText(context, 'Hide'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: HomiziColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RoommateSuggestedGrid extends StatelessWidget {
  const RoommateSuggestedGrid({
    required this.people,
    required this.requirements,
    required this.ask,
    required this.saved,
    required this.onInterested,
    required this.onDismiss,
    required this.onOpen,
    this.onMessage,
    super.key,
  });

  final List<FinderPerson> people;
  final FinderRequirements requirements;
  final RoommateAsk ask;
  final bool saved;
  final ValueChanged<FinderPerson> onInterested;
  final ValueChanged<FinderPerson> onDismiss;
  final ValueChanged<FinderPerson> onOpen;
  final ValueChanged<FinderPerson>? onMessage;

  @override
  Widget build(BuildContext context) {
    final preview = people.take(6).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  homiziText(context, 'Matched roommates'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              TextButton(
                key: const Key('roommate-matches-see-all'),
                onPressed: people.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => RoommateMatchesPage(
                              people: people,
                              requirements: requirements,
                              ask: ask,
                              saved: saved,
                              onInterested: onInterested,
                              onDismiss: onDismiss,
                              onOpen: onOpen,
                              onMessage: onMessage,
                            ),
                          ),
                        );
                      },
                child: Text(
                  homiziText(context, 'See All'),
                  style: const TextStyle(
                    color: HomiziColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const Key('roommate-suggestion-list'),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: preview.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, color: HomiziColors.line),
            itemBuilder: (context, index) {
              return _animated(index, _row(preview[index]));
            },
          ),
        ),
      ],
    );
  }

  Widget _row(FinderPerson person) {
    final percent = scoreFinderPerson(
      requirements,
      person,
      ask: ask,
      saved: saved,
    ).percent;
    return RoommateMatchRow(
      person: person,
      percent: percent,
      onOpen: () => onOpen(person),
      onInterested: () => onInterested(person),
      onDismiss: () => onDismiss(person),
      onMessage: onMessage == null ? null : () => onMessage!(person),
    );
  }
}

class RoommateMatchesPage extends StatefulWidget {
  const RoommateMatchesPage({
    required this.people,
    required this.requirements,
    required this.ask,
    required this.saved,
    required this.onInterested,
    required this.onDismiss,
    required this.onOpen,
    this.onMessage,
    super.key,
  });

  final List<FinderPerson> people;
  final FinderRequirements requirements;
  final RoommateAsk ask;
  final bool saved;
  final ValueChanged<FinderPerson> onInterested;
  final ValueChanged<FinderPerson> onDismiss;
  final ValueChanged<FinderPerson> onOpen;
  final ValueChanged<FinderPerson>? onMessage;

  @override
  State<RoommateMatchesPage> createState() => _RoommateMatchesPageState();
}

class _RoommateMatchesPageState extends State<RoommateMatchesPage> {
  late List<FinderPerson> _people = List.of(widget.people);

  void _dismiss(FinderPerson person) {
    widget.onDismiss(person);
    final next = [
      for (final other in _people)
        if (other.id != person.id) other,
    ];
    if (next.isEmpty) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _people = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('roommate-matches-page'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Matched roommates'))),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        itemCount: _people.length,
        separatorBuilder: (context, index) =>
            const Divider(height: 1, color: HomiziColors.line),
        itemBuilder: (context, index) {
          final person = _people[index];
          final percent = scoreFinderPerson(
            widget.requirements,
            person,
            ask: widget.ask,
            saved: widget.saved,
          ).percent;
          return _animated(
            index,
            RoommateMatchRow(
              person: person,
              percent: percent,
              onOpen: () => widget.onOpen(person),
              onInterested: () => widget.onInterested(person),
              onDismiss: () => _dismiss(person),
              onMessage: widget.onMessage == null
                  ? null
                  : () => widget.onMessage!(person),
            ),
          );
        },
      ),
    );
  }
}

Widget _animated(int index, Widget child) {
  return TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 220 + (index * 30).clamp(0, 180)),
    curve: Curves.easeOutCubic,
    builder: (context, value, child) {
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, (1 - value) * 8),
          child: child,
        ),
      );
    },
    child: child,
  );
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: buttonKey,
      style: TextButton.styleFrom(
        foregroundColor: HomiziColors.ink,
        backgroundColor: HomiziColors.accentWash,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
      child: Text(
        homiziText(context, label),
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}
