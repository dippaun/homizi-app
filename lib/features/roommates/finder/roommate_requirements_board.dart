import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/city_locality_field.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/priorities/priority_widgets.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/roommates/flatmate_shortcuts.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

/// Ranked roommate requirements, using the same rows as Set My Priorities.
class RoommateRequirementsBoard extends StatefulWidget {
  const RoommateRequirementsBoard({
    required this.initial,
    required this.onSave,
    this.headline = 'I want my roommate to be…',
    this.saveLabel = 'Save My Requirements',
    this.showPublish = true,
    this.showBriefLink = true,
    this.catalog = RoommateAskId.values,
    this.onClose,
    super.key,
  });

  final RoommateAsk initial;
  final Future<void> Function(RoommateAsk ask) onSave;
  final String headline;
  final String saveLabel;
  final bool showPublish;
  final bool showBriefLink;
  final List<RoommateAskId> catalog;
  final VoidCallback? onClose;

  @override
  State<RoommateRequirementsBoard> createState() =>
      _RoommateRequirementsBoardState();
}

class _RoommateRequirementsBoardState extends State<RoommateRequirementsBoard> {
  late RoommateAsk _draft = widget.initial;
  var _busy = false;

  @override
  void didUpdateWidget(covariant RoommateRequirementsBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initial != widget.initial && !_busy) {
      _draft = widget.initial;
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await widget.onSave(_draft);
    if (mounted) {
      setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final hidden = [
      for (final id in widget.catalog)
        if (!_draft.includes(id)) id,
    ];
    if (hidden.isEmpty) {
      return;
    }
    final picked = await showModalBottomSheet<RoommateAskId>(
      context: context,
      backgroundColor: HomiziColors.white,
      builder: (context) => SafeArea(
        child: ListView(
          key: const Key('roommate-add-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              homiziText(context, 'Add a preference'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final id in hidden)
              ListTile(
                key: Key('roommate-add-${id.name}'),
                leading: Icon(
                  roommateAskIcon(id),
                  color: HomiziColors.logoOrange,
                ),
                title: Text(homiziText(context, roommateAskTitle(id))),
                subtitle: Text(
                  homiziText(context, roommateAskValue(_draft, id)),
                ),
                onTap: () => Navigator.of(context).pop(id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _draft = _draft.added(picked));
    }
  }

  Future<void> _edit(RoommateAskId id) async {
    final next = await showModalBottomSheet<RoommateAsk>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomiziColors.white,
      builder: (context) => _AskEditSheet(
        value: _draft,
        id: id,
        canRemove: _draft.order.length > 3,
      ),
    );
    if (next != null && mounted) {
      setState(() => _draft = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranked = _draft.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onClose != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('roommate-wants-back'),
              onPressed: widget.onClose,
              icon: const Icon(Icons.arrow_back, color: HomiziColors.ink),
              label: Text(
                homiziText(context, 'Your Roommate Profile'),
                style: const TextStyle(color: HomiziColors.ink),
              ),
            ),
          ),
        if (widget.showBriefLink)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('flatmate-edit-profile'),
              onPressed: () => context.push(flatmateProfilePath),
              child: Text(
                homiziText(context, 'Edit full roommate brief'),
                style: const TextStyle(color: HomiziColors.ink),
              ),
            ),
          ),
        Expanded(
          child: ReorderableListView(
            key: const Key('roommate-requirements-list'),
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 24),
            header: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _Hint(headline: widget.headline),
            ),
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  key: const Key('roommate-add-preference'),
                  onPressed: _add,
                  icon: const Icon(Icons.add, color: HomiziColors.logoOrange),
                  label: Text(
                    homiziText(context, 'Add more preferences'),
                    style: const TextStyle(
                      color: HomiziColors.logoOrange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: HomiziColors.logoOrange),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                if (widget.showPublish) ...[
                  const SizedBox(height: 12),
                  Material(
                    color: HomiziColors.accentWash,
                    borderRadius: BorderRadius.circular(14),
                    child: SwitchListTile(
                      key: const Key('roommate-post-profile'),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      title: Text(
                        homiziText(context, 'Publish my roommate profile'),
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        homiziText(
                          context,
                          'Others can see you as a roommate seeker in Find Roomie.',
                        ),
                        style: const TextStyle(color: HomiziColors.inkSoft),
                      ),
                      value: _draft.profilePosted,
                      activeThumbColor: HomiziColors.logoOrange,
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(profilePosted: value),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                const PriorityTypeExplainer(),
                const SizedBox(height: 16),
                ShGradientButton(
                  buttonKey: const Key('roommate-requirements-save'),
                  label: widget.saveLabel,
                  busy: _busy,
                  onPressed: _busy ? null : () => unawaited(_save()),
                ),
              ],
            ),
            onReorderItem: (from, to) =>
                setState(() => _draft = _draft.moved(from, to)),
            children: [
              for (var i = 0; i < ranked.length; i++)
                PriorityRankRow(
                  key: ValueKey(ranked[i].name),
                  wire: 'ask-${ranked[i].name}',
                  index: i,
                  icon: roommateAskIcon(ranked[i]),
                  title: roommateAskTitle(ranked[i]),
                  value: roommateAskValue(_draft, ranked[i]),
                  note: roommateAskNote(ranked[i]),
                  mustHave: _draft.isMust(ranked[i]),
                  onToggleType: () =>
                      setState(() => _draft = _draft.toggled(ranked[i])),
                  onEdit: () => unawaited(_edit(ranked[i])),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.headline});

  final String headline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HomiziColors.accentWash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        homiziText(
          context,
          '$headline Drag to rank (P1 is highest). Tap a row to change it. Must have misses stay out of the top match band.',
        ),
        style: const TextStyle(
          color: HomiziColors.ink,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _AskEditSheet extends StatefulWidget {
  const _AskEditSheet({
    required this.value,
    required this.id,
    required this.canRemove,
  });

  final RoommateAsk value;
  final RoommateAskId id;
  final bool canRemove;

  @override
  State<_AskEditSheet> createState() => _AskEditSheetState();
}

class _AskEditSheetState extends State<_AskEditSheet> {
  late RoommateAsk _value = widget.value;
  late final TextEditingController _min = TextEditingController(
    text: '${widget.value.budgetMin}',
  );
  late final TextEditingController _max = TextEditingController(
    text: '${widget.value.budgetMax}',
  );
  late final TextEditingController _ageMin = TextEditingController(
    text: '${widget.value.ageMin}',
  );
  late final TextEditingController _ageMax = TextEditingController(
    text: '${widget.value.ageMax}',
  );
  late final TextEditingController _home = TextEditingController(
    text: widget.value.hometown,
  );
  String? _problem;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _ageMin.dispose();
    _ageMax.dispose();
    _home.dispose();
    super.dispose();
  }

  void _done() {
    var next = _value;
    if (widget.id == RoommateAskId.city) {
      if (_value.city.trim().isEmpty) {
        setState(() => _problem = 'Choose a city from the suggestions.');
        return;
      }
      next = _value;
    }
    if (widget.id == RoommateAskId.budget) {
      final low = int.tryParse(_min.text.trim());
      final high = int.tryParse(_max.text.trim());
      if (low == null || high == null || low < 1000 || high < low) {
        setState(
          () => _problem =
              'Enter a monthly budget, with the top at least the bottom.',
        );
        return;
      }
      next = next.copyWith(budgetMin: low, budgetMax: high);
    }
    if (widget.id == RoommateAskId.age) {
      final low = int.tryParse(_ageMin.text.trim());
      final high = int.tryParse(_ageMax.text.trim());
      if (low == null || high == null || low < 18 || high < low || high > 80) {
        setState(() => _problem = 'Use an age range from 18 upward.');
        return;
      }
      next = next.copyWith(ageMin: low, ageMax: high);
    }
    if (widget.id == RoommateAskId.hometown) {
      next = next.copyWith(hometown: _home.text.trim());
    }
    Navigator.of(context).pop(next);
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.id;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          key: const Key('roommate-ask-sheet'),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                homiziText(context, roommateAskTitle(id)),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (roommateAskNote(id) != null) ...[
                const SizedBox(height: 6),
                Text(
                  homiziText(context, roommateAskNote(id)!),
                  style: const TextStyle(color: HomiziColors.inkSoft),
                ),
              ],
              const SizedBox(height: 12),
              ..._fields(id),
              if (_problem != null) ...[
                const SizedBox(height: 8),
                Text(
                  homiziText(context, _problem!),
                  style: const TextStyle(color: HomiziColors.error),
                ),
              ],
              const SizedBox(height: 16),
              ShGradientButton(
                buttonKey: const Key('roommate-ask-done'),
                label: 'Done',
                onPressed: _done,
              ),
              if (widget.canRemove)
                TextButton(
                  key: const Key('roommate-ask-remove'),
                  onPressed: () =>
                      Navigator.of(context).pop(_value.removed(id)),
                  child: Text(
                    homiziText(context, 'Remove from my requirements'),
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _fields(RoommateAskId id) {
    if (id == RoommateAskId.city) {
      final pins = _value.pins.isNotEmpty
          ? _value.pins
          : [for (final name in _value.localityList) RoommatePin(name: name)];
      return [
        CityLocalityField(
          cityKey: const Key('roommate-ask-city'),
          localityKey: const Key('roommate-ask-localities'),
          addKey: const Key('roommate-ask-add-locality'),
          city: _value.city,
          localities: [
            for (final pin in pins)
              PickedPlace(
                label: pin.name,
                latitude: pin.latitude,
                longitude: pin.longitude,
              ),
          ],
          onChanged: (selection) {
            final names = [
              for (final place in selection.localities) place.label,
            ];
            setState(() {
              _value = _value.copyWith(
                city: selection.city,
                localities: names.join(', '),
                pins: [
                  for (final place in selection.localities)
                    RoommatePin(
                      name: place.label,
                      latitude: place.latitude,
                      longitude: place.longitude,
                    ),
                ],
              );
              _problem = null;
            });
          },
        ),
      ];
    }
    if (id == RoommateAskId.budget) {
      return [
        _money(_min, 'From (₹ / month)'),
        const SizedBox(height: 12),
        _money(_max, 'To (₹ / month)'),
      ];
    }
    if (id == RoommateAskId.age) {
      return [
        _money(_ageMin, 'From age'),
        const SizedBox(height: 12),
        _money(_ageMax, 'To age'),
      ];
    }
    if (id == RoommateAskId.hometown) {
      return [
        TextField(
          controller: _home,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Hometown or region'),
          ),
        ),
      ];
    }
    if (id == RoommateAskId.moveIn) {
      return [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(
            Icons.calendar_month_outlined,
            color: HomiziColors.logoOrange,
          ),
          title: Text(homiziText(context, 'Move in from')),
          subtitle: Text(roommateAskValue(_value, id)),
          onTap: () async {
            final now = DateTime.now();
            final first = DateTime(now.year, now.month, now.day);
            final current = _value.moveIn.isBefore(first)
                ? first
                : _value.moveIn;
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime(current.year, current.month, current.day),
              firstDate: first,
              lastDate: first.add(const Duration(days: 365)),
            );
            if (picked != null && mounted) {
              setState(
                () => _value = _value.copyWith(
                  moveYear: picked.year,
                  moveMonth: picked.month,
                  moveDay: picked.day,
                ),
              );
            }
          },
        ),
      ];
    }
    final options = roommateAskOptions(id);
    if (options.isEmpty) {
      return const [SizedBox.shrink()];
    }
    final multi = id == RoommateAskId.languages || id == RoommateAskId.hobbies;
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final entry in options.entries)
            _IconTile(
              tileKey: Key('roommate-ask-option-${entry.key}'),
              icon: roommateAskIcon(id),
              label: entry.value,
              selected: multi
                  ? (id == RoommateAskId.languages
                        ? _value.languages.contains(entry.key)
                        : _value.hobbies.contains(entry.key))
                  : _selected(id) == entry.key,
              onTap: () => setState(() => _value = _pick(id, entry.key, multi)),
            ),
        ],
      ),
    ];
  }

  Widget _money(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: homiziText(context, label)),
    );
  }

  String _selected(RoommateAskId id) {
    return switch (id) {
      RoommateAskId.gender => _value.gender,
      RoommateAskId.occupation => _value.occupation,
      RoommateAskId.schedule => _value.schedule,
      RoommateAskId.food => _value.food,
      RoommateAskId.cooking => _value.cooking,
      RoommateAskId.smoking => _value.smoking,
      RoommateAskId.drinking => _value.drinking,
      RoommateAskId.sleep => _value.sleep,
      RoommateAskId.cleanliness => '${_value.cleanliness}',
      RoommateAskId.guests => _value.guests,
      RoommateAskId.noise => _value.noise,
      RoommateAskId.pets => _value.pets,
      RoommateAskId.faith => _value.faith,
      RoommateAskId.chores => _value.chores,
      RoommateAskId.utilities => _value.utilities,
      RoommateAskId.room => _value.room,
      RoommateAskId.furnishing => _value.furnishing,
      RoommateAskId.lookingFor => _value.lookingFor,
      RoommateAskId.lease => '${_value.leaseMonths}',
      _ => '',
    };
  }

  RoommateAsk _pick(RoommateAskId id, String value, bool multi) {
    if (id == RoommateAskId.languages) {
      final next = [..._value.languages];
      next.contains(value) ? next.remove(value) : next.add(value);
      return _value.copyWith(languages: next);
    }
    if (id == RoommateAskId.hobbies) {
      final next = [..._value.hobbies];
      next.contains(value) ? next.remove(value) : next.add(value);
      return _value.copyWith(hobbies: next);
    }
    return switch (id) {
      RoommateAskId.gender => _value.copyWith(gender: value),
      RoommateAskId.occupation => _value.copyWith(occupation: value),
      RoommateAskId.schedule => _value.copyWith(schedule: value),
      RoommateAskId.food => _value.copyWith(food: value),
      RoommateAskId.cooking => _value.copyWith(cooking: value),
      RoommateAskId.smoking => _value.copyWith(smoking: value),
      RoommateAskId.drinking => _value.copyWith(drinking: value),
      RoommateAskId.sleep => _value.copyWith(sleep: value),
      RoommateAskId.cleanliness => _value.copyWith(
        cleanliness: int.tryParse(value) ?? _value.cleanliness,
      ),
      RoommateAskId.guests => _value.copyWith(guests: value),
      RoommateAskId.noise => _value.copyWith(noise: value),
      RoommateAskId.pets => _value.copyWith(pets: value),
      RoommateAskId.faith => _value.copyWith(faith: value),
      RoommateAskId.chores => _value.copyWith(chores: value),
      RoommateAskId.utilities => _value.copyWith(utilities: value),
      RoommateAskId.room => _value.copyWith(room: value),
      RoommateAskId.furnishing => _value.copyWith(furnishing: value),
      RoommateAskId.lookingFor => _value.copyWith(lookingFor: value),
      RoommateAskId.lease => _value.copyWith(
        leaseMonths: int.tryParse(value) ?? _value.leaseMonths,
      ),
      _ => _value,
    };
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.tileKey,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? HomiziColors.accentWash : HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? HomiziColors.logoOrange : HomiziColors.line,
        ),
      ),
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: HomiziColors.logoOrange),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
