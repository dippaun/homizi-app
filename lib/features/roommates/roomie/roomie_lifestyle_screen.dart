import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/roommates/roomie/roomie_widgets.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';

class RoomieLifestyleScreen extends ConsumerStatefulWidget {
  const RoomieLifestyleScreen({super.key});

  @override
  ConsumerState<RoomieLifestyleScreen> createState() =>
      _RoomieLifestyleScreenState();
}

class _RoomieLifestyleScreenState extends ConsumerState<RoomieLifestyleScreen> {
  final _note = TextEditingController();
  var _food = 'vegetarian';
  var _smoking = 'no';
  var _drinking = 'no';
  var _guests = 'rarely';
  var _cooking = 'cook_myself';
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(roomieProvider).brief;
    if (saved == null) {
      return;
    }
    _food = saved.food;
    _smoking = saved.smoking;
    _drinking = saved.drinking;
    _guests = saved.guests;
    _cooking = saved.cooking;
    _note.text = saved.lifestyleNote;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final existing = ref.read(roomieProvider).brief;
    final brief = (existing ?? _starter()).copyWith(
      food: _food,
      smoking: _smoking,
      drinking: _drinking,
      guests: _guests,
      cooking: _cooking,
      lifestyleNote: _note.text,
    );
    setState(() => _busy = true);
    ref.read(roomieProvider.notifier).save(brief);
    ref.read(searchPrioritiesProvider.notifier).applyBrief(brief);
    try {
      await ref
          .read(roommateProfileGatewayProvider)
          .save(
            brief.toRequirementDraft(),
            lifestyle: roomieLifestyleColumns(brief),
          );
    } on Object {
      // The brief is already on this device.
    }
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    unawaited(context.push(RoutePaths.roomieSaved));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoomiePage(
      title: 'Lifestyle & Preferences',
      body: ListView(
        key: const Key('roomie-lifestyle-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Container(
            key: const Key('roomie-lifestyle-banner'),
            color: HomiziColors.accentWash,
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, color: HomiziColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    homiziText(
                      context,
                      'Your lifestyle details will be visible only to verified & premium users.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: HomiziColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _section(
            'Smoking',
            const [
              _Tile('no', 'No', Icons.smoke_free),
              _Tile('yes', 'Yes', Icons.smoking_rooms),
              _Tile('undisclosed', 'Prefer not to say', Icons.help_outline),
            ],
            _smoking,
            (value) => setState(() => _smoking = value),
            'roomie-smoking',
          ),
          _section(
            'Drinking',
            const [
              _Tile('no', 'No', Icons.no_drinks),
              _Tile('yes', 'Yes', Icons.local_bar),
              _Tile('undisclosed', 'Prefer not to say', Icons.help_outline),
            ],
            _drinking,
            (value) => setState(() => _drinking = value),
            'roomie-drinking',
          ),
          _section(
            'Food Preference',
            const [
              _Tile('vegetarian', 'Vegetarian', Icons.eco),
              _Tile('non_vegetarian', 'Non-vegetarian', Icons.restaurant),
              _Tile('both', 'Both', Icons.restaurant_menu),
              _Tile('undisclosed', 'Prefer not to say', Icons.help_outline),
            ],
            _food,
            (value) => setState(() => _food = value),
            'roomie-food',
          ),
          _section(
            'Cooking',
            const [
              _Tile('cook_myself', 'Cook myself', Icons.soup_kitchen),
              _Tile('shared', 'Shared cooking', Icons.groups),
              _Tile('prefer_not', 'Prefer not to cook', Icons.no_meals),
            ],
            _cooking,
            (value) => setState(() => _cooking = value),
            'roomie-cooking',
          ),
          _section(
            'Guests',
            const [
              _Tile('frequently', 'Frequently', Icons.groups),
              _Tile('occasionally', 'Occasionally', Icons.group),
              _Tile('rarely', 'Rarely', Icons.person),
            ],
            _guests,
            (value) => setState(() => _guests = value),
            'roomie-guests',
          ),
          const RoomieSectionLabel('Other Lifestyle Notes (Optional)'),
          TextField(
            key: const Key('roomie-lifestyle-note'),
            controller: _note,
            maxLength: roomieLifestyleNoteMax,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: homiziText(
                context,
                'E.g. Quiet environment, early sleeper, pet friendly, etc.',
              ),
              filled: true,
              fillColor: HomiziColors.white,
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(color: HomiziColors.ink),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('roomie-lifestyle-save'),
              onPressed: _busy ? null : _save,
              child: Text(homiziText(context, 'Save Preferences')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    List<_Tile> tiles,
    String selected,
    ValueChanged<String> onSelected,
    String keyPrefix,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RoomieSectionLabel(title),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tile in tiles)
              _LifestyleTile(
                tileKey: Key('$keyPrefix-${tile.value}'),
                tile: tile,
                selected: selected == tile.value,
                onTap: () => onSelected(tile.value),
              ),
          ],
        ),
      ],
    );
  }
}

class _Tile {
  const _Tile(this.value, this.label, this.icon);

  final String value;
  final String label;
  final IconData icon;
}

class _LifestyleTile extends StatelessWidget {
  const _LifestyleTile({
    required this.tileKey,
    required this.tile,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final _Tile tile;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Material(
        color: selected ? HomiziColors.accentWash : HomiziColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? HomiziColors.accent : HomiziColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          key: tileKey,
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(tile.icon, color: HomiziColors.ink),
                      const SizedBox(height: 6),
                      Text(
                        homiziText(context, tile.label),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: HomiziColors.ink,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: HomiziColors.accent,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: HomiziColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

RoomieBrief _starter() {
  return RoomieBrief(
    budgetMinInr: 18000,
    budgetMaxInr: 32000,
    city: 'Bengaluru',
    localities: const ['Koramangala'],
    moveIn: DateTime.utc(2026, 12),
    occupation: 'Looking for a roomie',
    food: 'vegetarian',
    smoking: 'no',
    drinking: 'no',
    guests: 'rarely',
    cooking: 'cook_myself',
    genderPreference: 'any',
  );
}
