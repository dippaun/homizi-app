import 'package:flutter/material.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/city_locality_field.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/matching/match_bands.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/match_score.dart';
import 'package:homizi/features/roommates/finder/finder_models.dart';
import 'package:homizi/shared/widgets/homizi_full_photo_card.dart';

String finderHeadline(int? percent) {
  if (percent == null) {
    return 'Set preferences to see your match';
  }
  if (matchStrength(percent) == MatchStrength.strong && percent >= 85) {
    return 'Great Match!';
  }
  return matchStrengthLabel(matchStrength(percent));
}

class CompatibilityRing extends StatelessWidget {
  const CompatibilityRing({required this.percent, this.size = 72, super.key});

  final int? percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedMatchRing(
      percent: percent,
      size: size,
      labelKey: const Key('roommate-percent'),
    );
  }
}

class RoommateActionBar extends StatelessWidget {
  const RoommateActionBar({
    required this.onSkip,
    required this.onMaybe,
    required this.onInterested,
    this.interestedLabel = '',
    this.keyPrefix = 'roommate',
    super.key,
  });

  final VoidCallback onSkip;
  final VoidCallback onMaybe;
  final VoidCallback onInterested;
  final String interestedLabel;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundAction(
          actionKey: Key('$keyPrefix-skip'),
          tooltip: 'Skip',
          color: HomiziColors.white,
          border: HomiziColors.line,
          icon: Icons.close,
          iconColor: HomiziColors.error,
          label: interestedLabel.isEmpty ? null : 'Skip',
          onPressed: onSkip,
        ),
        _RoundAction(
          actionKey: Key('$keyPrefix-maybe'),
          tooltip: 'Maybe',
          color: HomiziColors.accentWash,
          border: HomiziColors.brandGolden,
          icon: Icons.star_rounded,
          iconColor: HomiziColors.ink,
          label: interestedLabel.isEmpty ? null : 'Maybe',
          onPressed: onMaybe,
        ),
        _RoundAction(
          actionKey: Key('$keyPrefix-interested'),
          tooltip: "I'm Interested",
          color: HomiziColors.logoOrange,
          border: HomiziColors.logoOrange,
          icon: Icons.favorite,
          iconColor: HomiziColors.ink,
          label: interestedLabel.isEmpty ? null : interestedLabel,
          onPressed: onInterested,
        ),
      ],
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.actionKey,
    required this.tooltip,
    required this.color,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.onPressed,
    this.label,
  });

  final Key actionKey;
  final String tooltip;
  final Color color;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final String? label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: HomiziColors.shadow,
      child: InkWell(
        key: actionKey,
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
    if (label == null) {
      return Tooltip(message: homiziText(context, tooltip), child: button);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(message: homiziText(context, tooltip), child: button),
        const SizedBox(height: 6),
        Text(
          homiziText(context, label!),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class RoommateStackCard extends StatelessWidget {
  const RoommateStackCard({
    required this.person,
    required this.index,
    required this.total,
    required this.onOpen,
    this.percent,
    this.onMatch,
    super.key,
  });

  final FinderPerson person;
  final int index;
  final int total;
  final VoidCallback onOpen;
  final VoidCallback? onMatch;

  /// Same [scoreMatch] percent the preview screen shows.
  final int? percent;

  @override
  Widget build(BuildContext context) {
    final photos = person.gallery.isEmpty
        ? [if (person.seeker.photoRef != null) person.seeker.photoRef!]
        : person.gallery;
    return HomiziFullPhotoCard(
      cardKey: const Key('roommate-card'),
      tapKey: Key('roommate-open-${person.id}'),
      photoHeight: 380,
      title: person.name,
      price: person.seeker.budgetLabel,
      locality: person.traits.city,
      person: true,
      photos: photos,
      verified: person.seeker.trust.anyIdentity,
      onTap: onOpen,
      match: percent == null
          ? null
          : HomiziPhotoMatch(
              percent: percent!,
              matchKey: Key('roommate-card-match-${person.id}'),
              onTap: onMatch,
            ),
      chips: [
        HomiziPhotoChip('${index + 1}/$total'),
        HomiziPhotoChip('${person.seeker.age} · ${person.group}'),
        HomiziPhotoChip(person.field),
        if (finderLifestyleChips(person).isNotEmpty)
          HomiziPhotoChip(
            finderLifestyleChips(person).first,
            tint: HomiziPhotoChipTint.wash,
          ),
      ],
      lines: [
        if (person.seeker.traits.thoughts.trim().isNotEmpty)
          '“${person.seeker.traits.thoughts.trim()}”',
      ],
    );
  }
}

class RoommateFilterSheet extends StatefulWidget {
  const RoommateFilterSheet({required this.initial, this.city = '', super.key});

  final FinderFilters initial;
  final String city;

  @override
  State<RoommateFilterSheet> createState() => _RoommateFilterSheetState();
}

class _RoommateFilterSheetState extends State<RoommateFilterSheet> {
  late FinderFilters _draft;
  late final TextEditingController _locality;
  late final TextEditingController _language;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
    _locality = TextEditingController(text: widget.initial.locality);
    _language = TextEditingController(text: widget.initial.language);
  }

  @override
  void dispose() {
    _locality.dispose();
    _language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: RepaintBoundary(
        key: const Key('roommate-filter-shot'),
        child: Material(
          key: const Key('roommate-filter-sheet'),
          color: HomiziColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottom),
            shrinkWrap: true,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HomiziColors.line,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                homiziText(context, 'Filter Roommates'),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                homiziText(context, 'Gender'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'any', label: Text('Any')),
                  ButtonSegment(value: 'man', label: Text('Male')),
                  ButtonSegment(value: 'woman', label: Text('Female')),
                ],
                selected: {_draft.gender},
                onSelectionChanged: (value) {
                  setState(() => _draft = _draft.copyWith(gender: value.first));
                },
              ),
              const SizedBox(height: 16),
              Text(
                homiziText(context, 'Budget (per person)'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: HomiziColors.ink,
                ),
              ),
              Text(
                '${formatInr(_draft.budgetMin)} – ${formatInr(_draft.budgetMax)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: HomiziColors.inkSoft,
                ),
              ),
              RangeSlider(
                key: const Key('roommate-budget'),
                min: 5000,
                max: 30000,
                divisions: 25,
                values: RangeValues(
                  _draft.budgetMin.toDouble().clamp(5000, 30000),
                  _draft.budgetMax.toDouble().clamp(5000, 30000),
                ),
                activeColor: HomiziColors.logoOrange,
                labels: RangeLabels(
                  formatInr(_draft.budgetMin),
                  formatInr(_draft.budgetMax),
                ),
                onChanged: (value) {
                  setState(() {
                    _draft = _draft.copyWith(
                      budgetMin: value.start.round(),
                      budgetMax: value.end.round(),
                    );
                  });
                },
              ),
              _choice(
                'Food',
                _draft.diet,
                const {'any': 'Any', 'veg': 'Veg', 'non_veg': 'Non-veg'},
                (value) =>
                    _draft = _draft.copyWith(diet: value, vegetarian: false),
              ),
              _choice(
                'Smoking',
                _draft.smoking,
                const {
                  'any': 'Any',
                  'never': 'Non-smoker',
                  'sometimes': 'Occasionally',
                  'regularly': 'Regularly',
                },
                (value) =>
                    _draft = _draft.copyWith(smoking: value, nonSmoker: false),
              ),
              _choice(
                'Drinking',
                _draft.drinking,
                const {
                  'any': 'Any',
                  'no': 'No',
                  'occasional': 'Occasional',
                  'yes': 'Yes',
                },
                (value) => _draft = _draft.copyWith(
                  drinking: value,
                  occasionalDrinking: false,
                ),
              ),
              _choice(
                'Sleep',
                _draft.sleep,
                const {
                  'any': 'Any',
                  'early': 'Early',
                  'flexible': 'Flexible',
                  'night': 'Night',
                },
                (value) => _draft = _draft.copyWith(sleep: value),
              ),
              _choice(
                'Cleanliness',
                '${_draft.cleanliness}',
                const {'0': 'Any', '3': '3+', '4': '4+', '5': '5'},
                (value) =>
                    _draft = _draft.copyWith(cleanliness: int.parse(value)),
              ),
              _choice(
                'Guests',
                _draft.guests,
                const {
                  'any': 'Any',
                  'rare': 'Rare',
                  'sometimes': 'Sometimes',
                  'often': 'Often',
                },
                (value) => _draft = _draft.copyWith(guests: value),
              ),
              _choice(
                'Pets',
                _draft.petFriendly ? 'ok' : 'any',
                const {'any': 'Any', 'ok': 'Pet friendly'},
                (value) => _draft = _draft.copyWith(petFriendly: value == 'ok'),
              ),
              _choice(
                'Work from home',
                _draft.wfh,
                const {
                  'any': 'Any',
                  'home': 'Home',
                  'hybrid': 'Hybrid',
                  'office': 'Office',
                },
                (value) => _draft = _draft.copyWith(wfh: value),
              ),
              Text(
                homiziText(
                  context,
                  'Age ${_draft.ageMin == 0 ? 'any' : _draft.ageMin}–${_draft.ageMax == 0 ? 'any' : _draft.ageMax}',
                ),
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              RangeSlider(
                key: const Key('roommate-age'),
                min: 18,
                max: 60,
                divisions: 42,
                values: RangeValues(
                  (_draft.ageMin == 0 ? 21 : _draft.ageMin).toDouble(),
                  (_draft.ageMax == 0 ? 35 : _draft.ageMax).toDouble(),
                ),
                activeColor: HomiziColors.logoOrange,
                onChanged: (value) {
                  setState(() {
                    _draft = _draft.copyWith(
                      ageMin: value.start.round(),
                      ageMax: value.end.round(),
                    );
                  });
                },
              ),
              TextField(
                key: const Key('roommate-language'),
                controller: _language,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Language'),
                ),
                onChanged: (value) =>
                    _draft = _draft.copyWith(language: value.trim()),
              ),
              const SizedBox(height: 8),
              PlaceAutocompleteField(
                fieldKey: const Key('roommate-preferred-location'),
                controller: _locality,
                labelText: homiziText(context, 'Preferred location'),
                hintText: homiziText(context, 'Search a locality'),
                includedPrimaryTypes: const ['sublocality', 'neighborhood'],
                nearbyLocalities: catalogLocalitySuggestions(widget.city),
                biasPoint: cityCentreFor(widget.city),
                onSelected: (place) {
                  final name = pickedLocalityName(place, widget.city);
                  if (name.isEmpty) {
                    return;
                  }
                  _locality.text = name;
                  setState(() => _draft = _draft.copyWith(locality: name));
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  homiziText(context, 'Move-in date'),
                  style: const TextStyle(color: HomiziColors.ink),
                ),
                subtitle: Text(
                  _draft.moveIn == null
                      ? homiziText(context, 'Any date')
                      : finderMoveInLabel(_draft.moveIn),
                  style: const TextStyle(color: HomiziColors.inkSoft),
                ),
                trailing: const Icon(Icons.event, color: HomiziColors.ink),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _draft.moveIn ?? DateTime.utc(2026, 11, 30),
                    firstDate: DateTime.utc(2026),
                    lastDate: DateTime.utc(2027, 12, 31),
                  );
                  if (picked == null) {
                    return;
                  }
                  setState(() {
                    _draft = _draft.copyWith(
                      moveIn: DateTime.utc(
                        picked.year,
                        picked.month,
                        picked.day,
                      ),
                    );
                  });
                },
              ),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('roommate-apply-filters'),
                style: FilledButton.styleFrom(
                  backgroundColor: HomiziColors.logoOrange,
                  foregroundColor: HomiziColors.ink,
                  minimumSize: const Size.fromHeight(48),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => Navigator.pop(context, _draft),
                child: Text(homiziText(context, 'Apply Filters')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _choice(
    String label,
    String selected,
    Map<String, String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: HomiziColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            children: [
              for (final entry in options.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: selected == entry.key,
                  onSelected: (_) => setState(() => onChanged(entry.key)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
