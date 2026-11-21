import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/listings/domain/poster_kind.dart';

/// Multi-select poster tiles. An empty selection means every type.
class PosterKindFilter extends StatelessWidget {
  const PosterKindFilter({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  bool _on(String kind) =>
      selected.isEmpty || selected.length >= posterKindOrder.length
      ? true
      : selected.contains(kind);

  void _toggle(String kind) {
    final current =
        selected.isEmpty || selected.length >= posterKindOrder.length
        ? List<String>.of(posterKindOrder)
        : List<String>.of(selected);
    if (current.contains(kind)) {
      current.remove(kind);
    } else {
      current.add(kind);
    }
    if (current.isEmpty || current.length >= posterKindOrder.length) {
      onChanged(const []);
      return;
    }
    onChanged(current);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('poster-kind-filter'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in posterKindOrder)
          _Tile(kind: kind, selected: _on(kind), onTap: () => _toggle(kind)),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.kind,
    required this.selected,
    required this.onTap,
  });

  final String kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? posterKindWash(kind) : HomiziColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('poster-filter-$kind'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? posterKindInk(kind) : HomiziColors.line,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(posterKindIcon(kind), size: 18, color: posterKindInk(kind)),
              const SizedBox(width: 6),
              Text(
                homiziText(context, posterKindLabel(kind)),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
