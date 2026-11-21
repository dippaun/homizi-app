import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
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
    super.key,
  });

  final FinderPerson person;
  final int? percent;
  final List<String> reasons;
  final VoidCallback onOpen;
  final VoidCallback onSkip;
  final VoidCallback onInterested;

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
    final portrait = (person.seeker.photoRef ?? '').trim().isNotEmpty
        ? person.seeker.photoRef!.trim()
        : (person.gallery.isEmpty ? '' : person.gallery.first);
    final age = person.seeker.age;
    final job = person.field.trim();
    final who = job.isEmpty ? '$age' : '$age · $job';
    return Material(
      key: Key('roommate-open-${person.id}'),
      color: HomiziColors.white,
      child: InkWell(
        onTap: widget.onOpen,
        child: Column(
          children: [
            Expanded(
              flex: 11,
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
                          Color(0x14000000),
                          Color(0xCC172033),
                        ],
                        stops: [0.35, 0.62, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: CompatibilityRing(percent: widget.percent, size: 64),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 18,
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
                            fontSize: 28,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FactChip(
                          icon: Icons.place_outlined,
                          label: person.seeker.localityLabel,
                        ),
                        _FactChip(
                          icon: Icons.payments_outlined,
                          label: person.seeker.budgetLabel,
                        ),
                        _FactChip(
                          icon: Icons.calendar_today_outlined,
                          label: person.seeker.moveInLabel,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in finderLifestyleChips(person))
                          _LifeChip(label: label),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _Reasons(reasons: widget.reasons, motion: _enter),
                    ),
                    Row(
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
                  ],
                ),
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
            color: HomiziColors.ink,
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
                        style: const TextStyle(color: HomiziColors.ink),
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
