import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Shown while saved preferences are read. Never the input form.
class PrefsSkeleton extends StatelessWidget {
  const PrefsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: Key('prefs-skeleton'),
      color: HomiziColors.white,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: HomiziColors.logoOrange,
          ),
        ),
      ),
    );
  }
}

/// One saved answer. A null [value] is an Add tile when [onAdd] is set,
/// and is hidden otherwise. "Not set" is never painted as body text.
class SavedField {
  const SavedField({
    required this.label,
    required this.icon,
    this.value,
    this.onAdd,
  });

  final String label;
  final IconData icon;
  final String? value;
  final VoidCallback? onAdd;

  bool get filled {
    final text = value?.trim() ?? '';
    if (text.isEmpty) {
      return false;
    }
    final lower = text.toLowerCase();
    return lower != 'not set' && lower != 'add' && !lower.startsWith('add ');
  }
}

/// Icon for a saved-summary label. Callers can pass their own icon instead.
IconData savedFieldIcon(String label) {
  final text = label.toLowerCase();
  if (text.contains('budget') || text.contains('rent')) {
    return Icons.currency_rupee;
  }
  if (text.contains('location') ||
      text.contains('commute') ||
      text.contains('city') ||
      text.contains('localit')) {
    return Icons.place_outlined;
  }
  if (text.contains('occupan') ||
      text.contains('bed') ||
      text.contains('room')) {
    return Icons.bed_outlined;
  }
  if (text.contains('property') ||
      text.contains('home') ||
      text.contains('bhk')) {
    return Icons.home_outlined;
  }
  if (text.contains('move')) {
    return Icons.calendar_month_outlined;
  }
  if (text.contains('gender')) {
    return Icons.wc_outlined;
  }
  if (text.contains('smok')) {
    return Icons.smoke_free;
  }
  if (text.contains('drink')) {
    return Icons.local_bar_outlined;
  }
  if (text.contains('food') || text.contains('veg') || text.contains('diet')) {
    return Icons.eco_outlined;
  }
  if (text.contains('language')) {
    return Icons.translate;
  }
  if (text.contains('furnish')) {
    return Icons.chair_outlined;
  }
  if (text.contains('lifestyle') || text.contains('habit')) {
    return Icons.spa_outlined;
  }
  if (text.contains('email')) {
    return Icons.mail_outline;
  }
  if (text.contains('mobile') || text.contains('phone')) {
    return Icons.phone_outlined;
  }
  if (text.contains('name')) {
    return Icons.badge_outlined;
  }
  return Icons.check_circle_outline;
}

/// Full saved-preferences view: check badge, one tile per field, edit button.
class SavedSummaryCard extends StatelessWidget {
  const SavedSummaryCard({
    required this.title,
    required this.onEdit,
    this.lines = const [],
    this.fields = const [],
    this.editLabel = 'Edit preferences',
    this.fill = false,
    this.cardKey = const Key('saved-summary-card'),
    this.editKey = const Key('saved-summary-edit'),
    super.key,
  });

  final String title;
  final List<String> lines;
  final List<SavedField> fields;
  final String editLabel;
  final VoidCallback onEdit;

  /// True when this view is the scaffold body and should fill the screen.
  final bool fill;
  final Key cardKey;
  final Key editKey;

  @override
  Widget build(BuildContext context) {
    final shown = fields.isNotEmpty ? fields : _fieldsFromLines(lines, onEdit);
    final visible = [
      for (final field in shown)
        if (field.filled || field.onAdd != null) field,
    ];
    final badge = title.replaceAll('✓', '').replaceAll('✔', '').trim();
    final tiles = [
      for (var index = 0; index < visible.length; index++)
        _SavedTile(field: visible[index], index: index),
    ];
    final button = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: FilledButton.icon(
        key: editKey,
        style: FilledButton.styleFrom(
          backgroundColor: HomiziColors.logoOrange,
          foregroundColor: HomiziColors.ink,
          minimumSize: const Size.fromHeight(52),
        ),
        onPressed: onEdit,
        icon: const Icon(Icons.edit_outlined),
        label: Text(
          homiziText(context, editLabel),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
    );
    final header = _SavedBadge(
      label: badge.isEmpty ? 'Preferences saved' : badge,
    );
    if (!fill) {
      return Padding(
        key: cardKey,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, ...tiles, button],
        ),
      );
    }
    return Column(
      key: cardKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 8),
            children: tiles,
          ),
        ),
        button,
      ],
    );
  }
}

List<SavedField> _fieldsFromLines(List<String> lines, VoidCallback onEdit) {
  final fields = <SavedField>[];
  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) {
      continue;
    }
    final split = line.split(':');
    if (split.length >= 2) {
      final label = split.first.trim();
      final value = split.sublist(1).join(':').trim();
      final field = SavedField(
        label: label,
        icon: savedFieldIcon(label),
        value: value,
        onAdd: onEdit,
      );
      if (field.filled || field.onAdd != null) {
        fields.add(field);
      }
      continue;
    }
    fields.add(
      SavedField(label: line, icon: savedFieldIcon(line), value: line),
    );
  }
  return fields;
}

class _SavedBadge extends StatelessWidget {
  const _SavedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(scale: 0.86 + (0.14 * value), child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: HomiziColors.successWash,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: HomiziColors.success,
                size: 40,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              homiziText(context, label),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                color: HomiziColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({required this.field, required this.index});

  final SavedField field;
  final int index;

  @override
  Widget build(BuildContext context) {
    final filled = field.filled;
    final palette = _palette(index);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index * 50).clamp(0, 280)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 12),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: filled ? _filled(context, palette) : _add(context),
      ),
    );
  }

  Widget _filled(BuildContext context, (Color, Color) palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.$1, HomiziColors.white],
        ),
        border: Border.all(color: palette.$2.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: HomiziColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(field.icon, color: palette.$2, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, field.label),
                    style: const TextStyle(
                      color: HomiziColors.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    homiziText(context, field.value!.trim()),
                    style: const TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _add(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        key: Key('saved-summary-add-${field.label}'),
        avatar: Icon(field.icon, size: 18, color: HomiziColors.logoOrange),
        label: Text(homiziText(context, 'Add ${field.label}')),
        onPressed: field.onAdd,
      ),
    );
  }
}

(Color, Color) _palette(int index) {
  const pairs = <(Color, Color)>[
    (HomiziColors.accentWash, HomiziColors.logoOrange),
    (HomiziColors.successWash, HomiziColors.success),
    (HomiziColors.homiziLavender, HomiziColors.homiziPurple),
    (Color(0xFFFFF1E8), HomiziColors.brandDeepOrange),
  ];
  return pairs[index % pairs.length];
}
