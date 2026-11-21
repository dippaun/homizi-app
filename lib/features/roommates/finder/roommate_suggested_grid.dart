import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/roommates/finder/roommate_qualities.dart';

/// Phone, large phone or tablet, then up to six columns on a wide desktop.
int roommateSuggestionColumns(double width) {
  if (width >= 1400) {
    return 6;
  }
  if (width >= 1180) {
    return 5;
  }
  if (width >= 960) {
    return 4;
  }
  if (width >= 600) {
    return 3;
  }
  return 2;
}

/// Instagram-style suggestions: circular photo, name, green percent,
/// and an orange Interested action. Dismissals are handled by the parent.
class RoommateSuggestedGrid extends StatefulWidget {
  const RoommateSuggestedGrid({
    required this.people,
    required this.requirements,
    required this.ask,
    required this.saved,
    required this.onInterested,
    required this.onDismiss,
    required this.onOpen,
    super.key,
  });

  final List<FinderPerson> people;
  final FinderRequirements requirements;
  final RoommateAsk ask;
  final bool saved;
  final ValueChanged<FinderPerson> onInterested;
  final ValueChanged<FinderPerson> onDismiss;
  final ValueChanged<FinderPerson> onOpen;

  @override
  State<RoommateSuggestedGrid> createState() => _RoommateSuggestedGridState();
}

class _RoommateSuggestedGridState extends State<RoommateSuggestedGrid> {
  var _all = false;

  @override
  Widget build(BuildContext context) {
    final shown = _all ? widget.people : widget.people.take(6).toList();
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
                onPressed: widget.people.length <= 6
                    ? null
                    : () => setState(() => _all = !_all),
                child: Text(
                  homiziText(context, _all ? 'Show less' : 'See All'),
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = roommateSuggestionColumns(constraints.maxWidth);
              return GridView.builder(
                key: const Key('roommate-suggestion-grid'),
                padding: const EdgeInsets.only(bottom: 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns >= 4 ? 0.72 : 0.62,
                ),
                itemCount: shown.length,
                itemBuilder: (context, index) {
                  final person = shown[index];
                  final percent = scoreFinderPerson(
                    widget.requirements,
                    person,
                    ask: widget.ask,
                    saved: widget.saved,
                  ).percent;
                  return _SuggestionTile(
                    person: person,
                    percent: percent,
                    onOpen: () => widget.onOpen(person),
                    onInterested: () => widget.onInterested(person),
                    onDismiss: () => widget.onDismiss(person),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.person,
    required this.percent,
    required this.onOpen,
    required this.onInterested,
    required this.onDismiss,
  });

  final FinderPerson person;
  final int? percent;
  final VoidCallback onOpen;
  final VoidCallback onInterested;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final first = person.name.trim().split(RegExp(r'\s+')).first;
    final line = person.field.trim().isNotEmpty
        ? person.field
        : person.seeker.localityLabel;
    return Material(
      color: HomiziColors.soft,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: Key('roommate-suggestion-${person.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  key: Key('roommate-dismiss-${person.id}'),
                  tooltip: homiziText(context, 'Hide'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: HomiziColors.ink,
                  ),
                ),
              ),
              _Face(person: person),
              const SizedBox(height: 8),
              Text(
                homiziText(context, '$first, ${person.seeker.age}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (percent != null) ...[
                const SizedBox(height: 4),
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
                ),
              ],
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: RoommateQualityIcons(person: person),
              ),
              const SizedBox(height: 4),
              Text(
                homiziText(context, line),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              _InterestedButton(
                buttonKey: Key('roommate-suggestion-interested-${person.id}'),
                onPressed: onInterested,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.person});

  final FinderPerson person;

  @override
  Widget build(BuildContext context) {
    final ref = person.seeker.photoRef?.trim();
    final photo = ref == null || ref.isEmpty ? null : ref;
    final cacheWidth = (84 * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(48, 512)
        .toInt();
    return ClipOval(
      child: SizedBox(
        width: 84,
        height: 84,
        child: photo == null
            ? const ColoredBox(
                color: HomiziColors.line,
                child: Icon(Icons.person, color: HomiziColors.ink),
              )
            : photo.startsWith('http')
            ? Image.network(
                photo,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stack) => _fallback(person),
              )
            : Image.asset(
                photo,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                errorBuilder: (context, error, stack) => _fallback(person),
              ),
      ),
    );
  }
}

Widget _fallback(FinderPerson person) {
  final parts = person.name.trim().split(RegExp(r'\s+'));
  final letters = parts.isEmpty
      ? 'H'
      : parts.length == 1
      ? parts.first[0]
      : '${parts.first[0]}${parts.last[0]}';
  return ColoredBox(
    color: HomiziColors.accentWash,
    child: Center(
      child: Text(
        letters.toUpperCase(),
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _InterestedButton extends StatelessWidget {
  const _InterestedButton({required this.buttonKey, required this.onPressed});

  final Key buttonKey;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [HomiziColors.brandGolden, HomiziColors.logoOrange],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: buttonKey,
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              homiziText(context, 'Interested'),
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
