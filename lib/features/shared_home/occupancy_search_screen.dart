import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/shared_home/domain/occupancy.dart';
import 'package:homizi/features/shared_home/shared_home_paths.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';

/// Which design the search screen follows.
enum OccupancyEntry {
  /// "Smart occupancy matching: Search a home".
  occupancy,

  /// "Find your roomie: share an existing home".
  roomie,
}

/// Search a home by actual room availability, or set roomie preferences
/// for a shared home. Both save one [OccupancyNeed].
class OccupancySearchScreen extends ConsumerStatefulWidget {
  const OccupancySearchScreen({
    super.key,
    this.entry = OccupancyEntry.occupancy,
    this.group = false,
  });

  final OccupancyEntry entry;

  /// Opens on "We are a group".
  final bool group;

  @override
  ConsumerState<OccupancySearchScreen> createState() =>
      _OccupancySearchScreenState();
}

class _OccupancySearchScreenState extends ConsumerState<OccupancySearchScreen> {
  late OccupancyNeed _need;
  final _min = TextEditingController();
  final _max = TextEditingController();
  TextEditingController? _place;
  var _touched = false;
  String? _note;

  bool get _roomie => widget.entry == OccupancyEntry.roomie;

  @override
  void initState() {
    super.initState();
    _apply(ref.read(occupancyNeedProvider));
    if (widget.group) {
      _need = _need.copyWith(mode: JoinMode.group);
    }
  }

  void _apply(OccupancyNeed need) {
    _need = need;
    _min.text = need.budgetMinInr > 0 ? '${need.budgetMinInr}' : '';
    _max.text = need.budgetMaxInr > 0 ? '${need.budgetMaxInr}' : '';
    _place?.text = need.locality;
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _edit(OccupancyNeed next) {
    setState(() {
      _need = next;
      _touched = true;
      _note = null;
    });
  }

  int _read(TextEditingController controller) =>
      int.tryParse(controller.text.replaceAll(RegExp('[^0-9]'), '')) ?? 0;

  Future<void> _find([OccupancyNeed? preset]) async {
    final need = (preset ?? _need).copyWith(
      budgetMinInr: _read(_min),
      budgetMaxInr: _read(_max),
      locality: (_place?.text ?? _need.locality).trim(),
    );
    final problem = need.problem;
    if (problem != null) {
      setState(() => _note = problem);
      return;
    }
    await ref.read(occupancyNeedProvider.notifier).save(need);
    if (!mounted) {
      return;
    }
    await context.push(
      SharedHomePaths.results(entry: _roomie ? 'roomie' : 'occupancy'),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, now.day);
    final current = _need.moveIn;
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(first)
          ? current
          : first,
      firstDate: first,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      _edit(_need.copyWith(moveIn: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(occupancyNeedProvider, (previous, next) {
      if (!_touched && next.saved) {
        setState(() => _apply(next));
      }
    });
    final text = Theme.of(context).textTheme;
    final title = _roomie ? 'Find your roomie' : 'Search a home';
    final subtitle = _roomie
        ? 'Set your preferences to find a compatible roomie or join a home where someone already lives.'
        : 'Find the right home based on actual room availability, not just BHK.';
    return Scaffold(
      key: Key(_roomie ? 'roomie-search-screen' : 'occ-search-screen'),
      backgroundColor: HomiziColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(
          homiziText(
            context,
            _roomie ? 'Share an existing home' : 'Smart occupancy matching',
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const Key('occ-search-list'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              homiziText(context, title),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(homiziText(context, subtitle), style: text.bodyMedium),
            const SizedBox(height: 16),
            if (_roomie) ..._roomieFields(context) else ..._occupancyFields(),
            if (!_need.saved && !_touched) ...[
              const SizedBox(height: 10),
              Text(
                homiziText(
                  context,
                  'Sample values shown. Change them to yours.',
                ),
                key: const Key('occ-sample-note'),
                style: text.bodySmall?.copyWith(color: HomiziColors.muted),
              ),
            ],
            if (_note != null) ...[
              const SizedBox(height: 10),
              Text(
                homiziText(context, _note!),
                key: const Key('occ-note'),
                style: const TextStyle(color: HomiziColors.error),
              ),
            ],
            const SizedBox(height: 16),
            ShGradientButton(
              buttonKey: Key(_roomie ? 'roomie-find' : 'occ-find'),
              icon: Icons.search,
              label: _roomie ? 'Find my roomie' : 'Find matching homes',
              onPressed: _find,
            ),
            const SizedBox(height: 20),
            if (!_roomie) ...[
              const ShHowItWorks(),
              const SizedBox(height: 16),
              _examples(context),
              const SizedBox(height: 16),
            ],
            _hostCard(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _occupancyFields() {
    return [
      SegmentedButton<JoinMode>(
        key: const Key('occ-mode'),
        segments: [
          ButtonSegment(
            value: JoinMode.individual,
            icon: const Icon(Icons.person_outline),
            label: Text(
              homiziText(context, 'I need a room'),
              key: const Key('occ-mode-individual'),
            ),
          ),
          ButtonSegment(
            value: JoinMode.group,
            icon: const Icon(Icons.groups_outlined),
            label: Text(
              homiziText(context, 'We are a group'),
              key: const Key('occ-mode-group'),
            ),
          ),
        ],
        selected: {_need.mode},
        onSelectionChanged: (value) => _edit(_need.copyWith(mode: value.first)),
      ),
      if (_need.mode == JoinMode.group) ...[
        const SizedBox(height: 12),
        _groupStepper(),
      ],
      const SizedBox(height: 14),
      ShSection(
        title: 'Desired occupancy',
        icon: Icons.bed_outlined,
        child: RadioGroup<DesiredOccupancy>(
          groupValue: _need.occupancy,
          onChanged: (value) {
            if (value != null) {
              _edit(_need.copyWith(occupancy: value));
            }
          },
          child: Column(
            children: [
              for (final option in DesiredOccupancy.values)
                RadioListTile<DesiredOccupancy>(
                  key: Key('occ-occupancy-${option.wire}'),
                  value: option,
                  contentPadding: EdgeInsets.zero,
                  activeColor: HomiziColors.brandOrange,
                  title: Text(homiziText(context, option.label)),
                  subtitle: Text(homiziText(context, '(${option.hint})')),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 14),
      ShSection(
        title: 'Preference',
        icon: Icons.tune,
        child: Column(
          children: [
            _budget(),
            const SizedBox(height: 12),
            _locality(),
            const SizedBox(height: 4),
            _moveIn(),
          ],
        ),
      ),
    ];
  }

  List<Widget> _roomieFields(BuildContext context) {
    return [
      ShSection(
        child: Column(
          children: [
            _budget(label: 'Budget (my share)'),
            const SizedBox(height: 4),
            _moveIn(),
            const Divider(height: 20),
            _dropdown(
              key: 'roomie-occupation',
              icon: Icons.work_outline,
              label: 'Occupation',
              value: _need.occupation,
              options: {for (final o in occupationOptions) o: o},
              onChanged: (value) => _edit(_need.copyWith(occupation: value)),
            ),
            const SizedBox(height: 12),
            _dropdown(
              key: 'roomie-food',
              icon: Icons.restaurant_outlined,
              label: 'Food preference',
              value: _need.food,
              options: foodOptions,
              onChanged: (value) => _edit(_need.copyWith(food: value)),
            ),
            const SizedBox(height: 12),
            _dropdown(
              key: 'roomie-gender',
              icon: Icons.wc_outlined,
              label: 'Housemate gender',
              value: _need.housemateGender,
              options: housemateGenderOptions,
              onChanged: (value) =>
                  _edit(_need.copyWith(housemateGender: value)),
            ),
            const SizedBox(height: 12),
            _ageRange(),
            const Divider(height: 20),
            _locality(),
          ],
        ),
      ),
      const SizedBox(height: 14),
      ShSection(
        title: 'Looking for',
        icon: Icons.home_outlined,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('roomie-looking-individual'),
              label: Text(homiziText(context, 'A room in a shared home')),
              selected: _need.mode == JoinMode.individual,
              onSelected: (_) =>
                  _edit(_need.copyWith(mode: JoinMode.individual)),
            ),
            ChoiceChip(
              key: const Key('roomie-looking-group'),
              label: Text(homiziText(context, 'Rooms for me and friends')),
              selected: _need.mode == JoinMode.group,
              onSelected: (_) => _edit(_need.copyWith(mode: JoinMode.group)),
            ),
            if (_need.mode == JoinMode.group) _groupStepper(),
          ],
        ),
      ),
    ];
  }

  Widget _groupStepper() {
    return Row(
      key: const Key('occ-group'),
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.groups_outlined, color: HomiziColors.brandOrange),
        const SizedBox(width: 8),
        Text(homiziText(context, 'People in your group')),
        IconButton(
          key: const Key('occ-group-minus'),
          tooltip: homiziText(context, 'Fewer people'),
          onPressed: _need.groupSize > 2
              ? () => _edit(_need.copyWith(groupSize: _need.groupSize - 1))
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text(
          '${_need.groupSize}',
          key: const Key('occ-group-size'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        IconButton(
          key: const Key('occ-group-plus'),
          tooltip: homiziText(context, 'More people'),
          onPressed: _need.groupSize < 6
              ? () => _edit(_need.copyWith(groupSize: _need.groupSize + 1))
              : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Widget _budget({String label = 'Budget per person / month'}) {
    InputDecoration deco(String hint) => InputDecoration(
      labelText: homiziText(context, hint),
      prefixText: '₹ ',
      isDense: true,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.currency_rupee, color: HomiziColors.brandOrange),
            const SizedBox(width: 8),
            Text(
              homiziText(context, label),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('occ-budget-min'),
                controller: _min,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: deco('From'),
                onChanged: (_) => _touched = true,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('–'),
            ),
            Expanded(
              child: TextField(
                key: const Key('occ-budget-max'),
                controller: _max,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: deco('To'),
                onChanged: (_) => _touched = true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _locality() {
    return Autocomplete<String>(
      key: const Key('occ-locality-field'),
      initialValue: TextEditingValue(text: _need.locality),
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) {
          return sharedHomeLocalities;
        }
        return sharedHomeLocalities.where(
          (option) => option.toLowerCase().contains(query),
        );
      },
      onSelected: (value) => _edit(_need.copyWith(locality: value)),
      fieldViewBuilder: (context, controller, focus, onSubmitted) {
        _place = controller;
        return TextField(
          key: const Key('occ-locality'),
          controller: controller,
          focusNode: focus,
          decoration: InputDecoration(
            labelText: homiziText(context, 'Location'),
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              color: HomiziColors.brandOrange,
            ),
            isDense: true,
          ),
          onChanged: (_) => _touched = true,
        );
      },
    );
  }

  Widget _moveIn() {
    final date = _need.moveIn;
    return ListTile(
      key: const Key('occ-move-in'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.calendar_month_outlined,
        color: HomiziColors.brandOrange,
      ),
      title: Text(homiziText(context, 'Move-in date')),
      trailing: Text(
        date == null ? homiziText(context, 'Pick a date') : formatMoveIn(date),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: HomiziColors.ink,
        ),
      ),
      onTap: _pickDate,
    );
  }

  Widget _ageRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cake_outlined, color: HomiziColors.brandOrange),
            const SizedBox(width: 8),
            Expanded(child: Text(homiziText(context, 'Housemate age'))),
            Text(
              '${_need.ageMin} – ${_need.ageMax} ${homiziText(context, 'years')}',
              key: const Key('roomie-age-label'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        RangeSlider(
          key: const Key('roomie-age'),
          min: 18,
          max: 60,
          divisions: 42,
          activeColor: HomiziColors.brandOrange,
          values: RangeValues(
            _need.ageMin.toDouble().clamp(18, 60),
            _need.ageMax.toDouble().clamp(18, 60),
          ),
          onChanged: (value) => _edit(
            _need.copyWith(
              ageMin: value.start.round(),
              ageMax: value.end.round(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String key,
    required IconData icon,
    required String label,
    required String value,
    required Map<String, String> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      key: Key(key),
      initialValue: options.containsKey(value) ? value : options.keys.first,
      decoration: InputDecoration(
        labelText: homiziText(context, label),
        prefixIcon: Icon(icon, color: HomiziColors.brandOrange),
        isDense: true,
      ),
      items: [
        for (final entry in options.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(homiziText(context, entry.value)),
          ),
      ],
      onChanged: (next) {
        if (next != null) {
          onChanged(next);
        }
      },
    );
  }

  Widget _examples(BuildContext context) {
    final rows = [
      (
        'occ-example-double',
        'assets/images/real/living_b.webp',
        '2 BHK – Room sharing',
        'Total rooms: 2 · Available for 4 persons (double occupancy)',
        'Ideal for friends or cost sharing',
        _need.copyWith(occupancy: DesiredOccupancy.double),
      ),
      (
        'occ-example-flexible',
        'assets/images/real/living.webp',
        '3 BHK – Multiple options',
        'Total rooms: 3 · Available for 3–6 persons (single or double)',
        'Choose single or double occupancy per room',
        _need.copyWith(occupancy: DesiredOccupancy.flexible),
      ),
      (
        'occ-example-studio',
        'assets/images/real/bedroom.webp',
        '1 RK / Studio',
        'Total rooms: 1 · Available for 1–2 persons',
        'Ideal for individuals or a couple',
        _need.copyWith(occupancy: DesiredOccupancy.flexible),
      ),
    ];
    final text = Theme.of(context).textTheme;
    return ShSection(
      title: 'Other occupancy examples on HOMIZI',
      icon: Icons.apartment_outlined,
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: HomiziColors.soft,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  key: Key(row.$1),
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _find(row.$6),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            row.$2,
                            width: 72,
                            height: 64,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                homiziText(context, row.$3),
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                homiziText(context, row.$4),
                                style: text.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '→ ${homiziText(context, row.$5)}',
                                style: text.bodySmall?.copyWith(
                                  color: HomiziColors.brandDeepRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _hostCard(BuildContext context) {
    return Material(
      color: HomiziColors.accentWash,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: const Key('occ-post-home'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(SharedHomePaths.host),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.add_home_outlined,
                color: HomiziColors.brandDeepRed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      homiziText(context, 'Hosts, owners and existing tenants'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: HomiziColors.ink,
                      ),
                    ),
                    Text(
                      homiziText(
                        context,
                        'Post a shared home: add total rooms, who lives there and the vacant rooms.',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// "₹10,000 – ₹20,000".
String budgetLine(OccupancyNeed need) =>
    '${formatInr(need.budgetMinInr)} – ${formatInr(need.budgetMaxInr)}';
