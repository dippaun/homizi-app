import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/photo_source.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/browse/browse_place.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/features/roommates/finder/finder_widgets.dart';

/// Full-width profile card for the Find Roomie deck.
class RoommateDeckCard extends StatefulWidget {
  const RoommateDeckCard({
    required this.person,
    required this.percent,
    required this.reasons,
    required this.onOpen,
    required this.onSkip,
    required this.onInterested,
    this.quiet = false,
    this.viewerCity = '',
    super.key,
  });

  final FinderPerson person;
  final int? percent;
  final List<String> reasons;
  final VoidCallback onOpen;
  final VoidCallback onSkip;
  final VoidCallback onInterested;

  /// Back card in the stack. No buttons, so the front card stays the control.
  final bool quiet;

  /// The viewer's city. A different city draws the city chip.
  final String viewerCity;

  @override
  State<RoommateDeckCard> createState() => _RoommateDeckCardState();
}

class _RoommateDeckCardState extends State<RoommateDeckCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 640),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant RoommateDeckCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _enter.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final person = widget.person;
    final portrait = personPortrait(
      personId: person.id,
      photoRef: person.seeker.photoRef,
      gallery: person.gallery,
    );
    final otherCity = differentCityNote(person.traits.city, widget.viewerCity);
    final age = person.seeker.age;
    final job = person.field.trim();
    final who = job.isEmpty ? '$age' : '$age · $job';
    final facts = [
      (Icons.place_outlined, person.seeker.localityLabel),
      (Icons.payments_outlined, person.seeker.budgetLabel),
      (Icons.calendar_today_outlined, person.seeker.moveInLabel),
    ];
    final life = finderLifestyleChips(person);
    return Material(
      key: Key('roommate-open-${person.id}'),
      color: HomiziColors.ink,
      clipBehavior: Clip.antiAlias,
      borderRadius: const BorderRadius.all(Radius.circular(28)),
      child: InkWell(
        onTap: widget.quiet ? null : widget.onOpen,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ListingPhoto(
              asset: portrait,
              semanticLabel: person.name,
              alignment: Alignment.topCenter,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00000000),
                    Color(0x00000000),
                    Color(0xF0172033),
                  ],
                  stops: [0.28, 0.48, 1],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: HomiziColors.white,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: CompatibilityRing(percent: widget.percent, size: 58),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: widget.quiet ? 18 : 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: HomiziColors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    who,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomiziColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (otherCity != null)
                        _EnterChip(
                          motion: _enter,
                          index: 0,
                          child: KeyedSubtree(
                            key: Key('different-city-${person.id}'),
                            child: _FactChip(
                              icon: Icons.location_city_outlined,
                              label: otherCity,
                            ),
                          ),
                        ),
                      for (var i = 0; i < facts.length; i++)
                        _EnterChip(
                          motion: _enter,
                          index: i,
                          child: _FactChip(
                            icon: facts[i].$1,
                            label: facts[i].$2,
                          ),
                        ),
                      for (var i = 0; i < life.length; i++)
                        _EnterChip(
                          motion: _enter,
                          index: facts.length + i,
                          child: _LifeChip(label: life[i]),
                        ),
                    ],
                  ),
                  if (!widget.quiet) ...[
                    const SizedBox(height: 10),
                    _Reasons(reasons: widget.reasons, motion: _enter),
                  ],
                ],
              ),
            ),
            if (!widget.quiet)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _DeckButton(
                      actionKey: const Key('roommate-skip'),
                      tooltip: 'Skip',
                      icon: Icons.close,
                      fill: HomiziColors.white,
                      border: HomiziColors.line,
                      iconColor: HomiziColors.error,
                      onPressed: widget.onSkip,
                    ),
                    const SizedBox(width: 28),
                    _DeckButton(
                      actionKey: const Key('roommate-interested'),
                      tooltip: "I'm Interested",
                      icon: Icons.favorite,
                      fill: HomiziColors.logoOrange,
                      border: HomiziColors.logoOrange,
                      iconColor: HomiziColors.white,
                      onPressed: widget.onInterested,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Reasons extends StatelessWidget {
  const _Reasons({required this.reasons, required this.motion});

  final List<String> reasons;
  final Animation<double> motion;

  @override
  Widget build(BuildContext context) {
    final lines = reasons.take(3).toList();
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'Why this match'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < lines.length; i++)
          FadeTransition(
            opacity: CurvedAnimation(
              parent: motion,
              curve: Interval(0.15 + i * 0.2, 1, curve: Curves.easeOut),
            ),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: motion,
                      curve: Interval(0.15 + i * 0.2, 1, curve: Curves.easeOut),
                    ),
                  ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 16,
                      color: HomiziColors.logoOrange,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lines[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: HomiziColors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _EnterChip extends StatelessWidget {
  const _EnterChip({
    required this.motion,
    required this.index,
    required this.child,
  });

  final Animation<double> motion;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (0.08 * index).clamp(0.0, 0.7);
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: motion,
        curve: Interval(start, 1, curve: Curves.easeOut),
      ),
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
            .animate(
              CurvedAnimation(
                parent: motion,
                curve: Interval(start, 1, curve: Curves.easeOut),
              ),
            ),
        child: child,
      ),
    );
  }
}

class _FactChip extends StatelessWidget {
  const _FactChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.mist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: HomiziColors.logoOrange),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LifeChip extends StatelessWidget {
  const _LifeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.homiziLavender,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon(label), size: 16, color: HomiziColors.homiziPurple),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('pet')) {
      return Icons.pets;
    }
    if (lower.contains('smok')) {
      return Icons.smoke_free;
    }
    if (lower.contains('drink')) {
      return Icons.local_bar_outlined;
    }
    if (lower.contains('veg')) {
      return Icons.restaurant_outlined;
    }
    return Icons.favorite_border;
  }
}

class _DeckButton extends StatelessWidget {
  const _DeckButton({
    required this.actionKey,
    required this.tooltip,
    required this.icon,
    required this.fill,
    required this.border,
    required this.iconColor,
    required this.onPressed,
  });

  final Key actionKey;
  final String tooltip;
  final IconData icon;
  final Color fill;
  final Color border;
  final Color iconColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: actionKey,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: iconColor,
        fixedSize: const Size(64, 64),
        side: BorderSide(color: border, width: 1.5),
      ),
      icon: Icon(icon, size: 28),
    );
  }
}
