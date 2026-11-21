import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/features/listings/domain/poster_kind.dart';

/// Coloured type chip shown beside a name. Icon plus label, no plain text.
class PosterKindBadge extends StatelessWidget {
  const PosterKindBadge({required this.kind, this.badgeKey, super.key});

  /// Wire value (`owner`, `pg`, `broker`, `room_sharer`) or a display label.
  final String kind;
  final Key? badgeKey;

  @override
  Widget build(BuildContext context) {
    final wire = isPosterKind(kind) ? kind : posterKindFromHostLabel(kind);
    final label = posterKindLabel(wire);
    return Semantics(
      label: label,
      child: DecoratedBox(
        key: badgeKey ?? Key('poster-badge-$wire'),
        decoration: BoxDecoration(
          color: posterKindWash(wire),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(posterKindIcon(wire), size: 14, color: posterKindInk(wire)),
              const SizedBox(width: 4),
              Text(
                homiziText(context, label),
                style: TextStyle(
                  color: posterKindInk(wire),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
