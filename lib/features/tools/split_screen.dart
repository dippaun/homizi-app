import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/payments/domain/payment_rules.dart';
import 'package:homizi/features/payments/payment_gateway.dart';
import 'package:homizi/features/tools/domain/smart_split.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';
import 'package:homizi/features/tools/rent_split/rent_split_repository.dart';

/// Seed localities for the picker. Any place can be typed.
const splitSeedLocalities = <String>[
  'Andheri East, Mumbai',
  'Powai, Mumbai',
  'Koramangala, Bengaluru',
  'HSR Layout, Bengaluru',
  'Indiranagar, Bengaluru',
  'Baner, Pune',
  'Viman Nagar, Pune',
  'Gachibowli, Hyderabad',
  'Velachery, Chennai',
  'Sector 62, Noida',
];

enum SplitStep { setup, rooms, result, review, done }

/// Smart Rent Split: property → rooms & occupancy → result → review & agree
/// → confirmation. Works on the device; the server copy is optional.
class SplitScreen extends ConsumerStatefulWidget {
  const SplitScreen({
    super.key,
    this.roommates = const [],
    this.initialBhk,
    this.initialLocality,
    this.initialRentInr,
  });

  /// First names to prefill, e.g. from a mutual-interest roommate list.
  final List<String> roommates;

  /// Prefill from a shared home, e.g. `3 BHK`, `Andheri East, Mumbai`.
  final String? initialBhk;
  final String? initialLocality;
  final int? initialRentInr;

  @override
  ConsumerState<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends ConsumerState<SplitScreen> {
  SplitStep _step = SplitStep.setup;
  late String _bhk = splitBhkOptions.contains(widget.initialBhk)
      ? widget.initialBhk!
      : '3 BHK';
  late final _locality = TextEditingController(
    text: (widget.initialLocality ?? '').trim().isEmpty
        ? 'Andheri East, Mumbai'
        : widget.initialLocality!.trim(),
  );
  late final _rent = TextEditingController(
    text: (widget.initialRentInr ?? 0) > 0
        ? '${widget.initialRentInr}'
        : '30000',
  );
  final _maintenance = TextEditingController();
  final _utilities = TextEditingController();
  late int _people = widget.roommates.isEmpty
      ? 3
      : (widget.roommates.length + 1).clamp(1, 12);
  SplitHome _home = const SplitHome(bhk: '3 BHK', locality: '', rentInr: 0);
  List<SplitRoom> _rooms = const [];
  String? _roomsFor;
  SplitMode _mode = SplitMode.smart;
  final _custom = <int, TextEditingController>{};
  final _agreed = <int>{};
  String? _note;
  var _busy = false;
  SavedRentSplit? _saved;
  bool _savedRemotely = false;
  PaymentRecord? _paid;
  List<SavedRentSplit> _history = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadHistory());
  }

  @override
  void dispose() {
    _locality.dispose();
    _rent.dispose();
    _maintenance.dispose();
    _utilities.dispose();
    for (final c in _custom.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final list = await ref.read(rentSplitRepositoryProvider).list();
    if (mounted) {
      setState(() => _history = list);
    }
  }

  SplitOutcome get _outcome => computeSplit(
    home: _home,
    rooms: _rooms,
    mode: _mode,
    custom: {
      for (final e in _custom.entries) e.key: wholeRupees(e.value.text) ?? 0,
    },
  );

  void _go(SplitStep step) {
    setState(() {
      _step = step;
      _note = null;
    });
  }

  void _back() {
    switch (_step) {
      case SplitStep.rooms:
        _go(SplitStep.setup);
      case SplitStep.result:
        _go(SplitStep.rooms);
      case SplitStep.review:
        _go(SplitStep.result);
      case SplitStep.setup:
      case SplitStep.done:
        HomiziBackButton.leave(context);
    }
  }

  void _toRooms() {
    final rent = wholeRupees(_rent.text);
    final maintenance = _maintenance.text.trim().isEmpty
        ? 0
        : wholeRupees(_maintenance.text);
    final utilities = _utilities.text.trim().isEmpty
        ? 0
        : wholeRupees(_utilities.text);
    final place = _locality.text.trim();
    if (rent == null || rent <= 0) {
      setState(() => _note = 'Enter the monthly rent in whole rupees.');
      return;
    }
    if (maintenance == null || utilities == null) {
      setState(
        () => _note = 'Enter whole rupees for maintenance and utilities.',
      );
      return;
    }
    if (place.isEmpty) {
      setState(() => _note = 'Add the locality.');
      return;
    }
    final capacity = bedroomsFor(_bhk) * maxPeoplePerRoom;
    if (_people > capacity) {
      setState(
        () => _note = 'A $_bhk fits up to $capacity people at 3 per room.',
      );
      return;
    }
    final key = '$_bhk/$_people';
    setState(() {
      _home = SplitHome(
        bhk: _bhk,
        locality: place,
        rentInr: rent,
        maintenanceInr: maintenance,
        utilitiesInr: utilities,
      );
      if (_roomsFor != key) {
        _rooms = defaultRooms(
          _bhk,
          _people,
          names: ['You', ...widget.roommates],
        );
        _roomsFor = key;
        _resetCustom();
      }
      _step = SplitStep.rooms;
      _note = null;
    });
  }

  void _resetCustom() {
    for (final c in _custom.values) {
      c.dispose();
    }
    _custom.clear();
    _agreed.clear();
  }

  void _setOccupancy(int room, int count) {
    final current = _rooms[room].occupants;
    final total = peopleIn(_rooms).length;
    final next = [...current];
    var serial = total;
    while (next.length < count) {
      serial += 1;
      next.add('Roommate $serial');
    }
    while (next.length > count) {
      next.removeLast();
    }
    setState(() {
      _rooms = [
        for (var i = 0; i < _rooms.length; i++)
          i == room ? _rooms[i].copyWith(occupants: next) : _rooms[i],
      ];
      _people = peopleIn(_rooms).length;
      _roomsFor = '$_bhk/$_people';
      _resetCustom();
    });
  }

  Future<void> _editRoom(int index) async {
    final next = await showModalBottomSheet<SplitRoom>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomiziColors.white,
      builder: (context) =>
          _RoomSheet(title: roomTitle(_rooms, index), room: _rooms[index]),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() {
      _rooms = [
        for (var i = 0; i < _rooms.length; i++) i == index ? next : _rooms[i],
      ];
    });
  }

  void _toResult() {
    if (peopleIn(_rooms).isEmpty) {
      setState(() => _note = 'Add at least one person to a room.');
      return;
    }
    _go(SplitStep.result);
  }

  void _setMode(SplitMode mode) {
    setState(() {
      if (mode == SplitMode.custom && _custom.isEmpty) {
        final smart = computeSplit(
          home: _home,
          rooms: _rooms,
          mode: SplitMode.smart,
        );
        for (var i = 0; i < smart.shares.length; i++) {
          _custom[i] = TextEditingController(
            text: '${smart.shares[i].rentInr}',
          );
        }
      }
      _mode = mode;
      _agreed.clear();
    });
  }

  Future<void> _copySummary() async {
    final outcome = _outcome;
    await Clipboard.setData(
      ClipboardData(
        text: splitSummaryText(
          home: _home,
          rooms: _rooms,
          mode: _mode,
          shares: outcome.shares,
        ),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            homiziText(context, 'Summary copied. Paste it in your flat chat.'),
          ),
        ),
      );
    }
  }

  Future<void> _finalize() async {
    final outcome = _outcome;
    setState(() => _busy = true);
    final split = SavedRentSplit(
      id: newLocalId(),
      home: _home,
      rooms: _rooms,
      mode: _mode,
      shares: outcome.shares,
      agreed: [
        for (final i in _agreed.toList()..sort()) outcome.shares[i].name,
      ],
      finalizedAt: DateTime.now(),
    );
    final repo = ref.read(rentSplitRepositoryProvider);
    final remote = await repo.save(split);
    final history = await repo.list();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _saved = split;
      _savedRemotely = remote;
      _history = history;
      _paid = null;
      _step = SplitStep.done;
    });
  }

  Future<void> _payMyShare() async {
    final split = _saved;
    if (split == null || split.shares.isEmpty) {
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      final gateway = ref.read(rentSplitPaymentsProvider);
      final mine = split.shares.first;
      final session = await gateway.start(
        matchId: 'rent-split-${split.id}',
        kind: PaymentKind.rent,
        amountInr: mine.totalInr,
        counterpartyName: 'Flat rent pool · ${split.home.locality}',
        periodLabel: 'This month',
      );
      final done = await gateway.completeDemo(
        paymentId: session.payment.id,
        success: true,
      );
      if (mounted) {
        setState(() => _paid = done);
      }
    } on PaymentFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _startOver() {
    setState(() {
      _step = SplitStep.setup;
      _saved = null;
      _paid = null;
      _mode = SplitMode.smart;
      _resetCustom();
      _note = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: HomiziBackButton(onPressed: _back),
        title: Text(homiziText(context, 'Rent split')),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: Key('split-step-${_step.name}'),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            if (_step != SplitStep.done) _Steps(step: _step),
            ...switch (_step) {
              SplitStep.setup => _setup(context),
              SplitStep.rooms => _roomsStep(context),
              SplitStep.result => _result(context),
              SplitStep.review => _review(context),
              SplitStep.done => _done(context),
            },
            if (_note != null) ...[
              const SizedBox(height: 12),
              Text(
                homiziText(context, _note!),
                key: const Key('split-note'),
                style: const TextStyle(
                  color: HomiziColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  TextStyle? _h1(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineSmall
      ?.copyWith(fontWeight: FontWeight.w700, color: HomiziColors.ink);

  List<Widget> _setup(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return [
      Text(homiziText(context, 'Set up rent split'), style: _h1(context)),
      const SizedBox(height: 4),
      Text(
        homiziText(
          context,
          'Work out each person’s share from room size, attached bathroom, and who lives where.',
        ),
        style: text.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
      ),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.asset(
            'assets/photos/living_05.webp',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) =>
                const ColoredBox(color: HomiziColors.soft),
          ),
        ),
      ),
      const SizedBox(height: 16),
      _Section(
        icon: Icons.home_outlined,
        title: 'Property details',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in splitBhkOptions)
                  ChoiceChip(
                    key: Key('split-bhk-$option'),
                    label: Text(homiziText(context, option)),
                    selected: _bhk == option,
                    selectedColor: HomiziColors.accentWash,
                    side: BorderSide(
                      color: _bhk == option
                          ? HomiziColors.logoOrange
                          : HomiziColors.line,
                    ),
                    onSelected: (_) => setState(() {
                      _bhk = option;
                      _people = _people.clamp(
                        1,
                        bedroomsFor(option) * maxPeoplePerRoom,
                      );
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _locality.text),
              optionsBuilder: (value) {
                final q = value.text.trim().toLowerCase();
                if (q.isEmpty) {
                  return const Iterable<String>.empty();
                }
                return splitSeedLocalities.where(
                  (place) => place.toLowerCase().contains(q),
                );
              },
              onSelected: (value) => _locality.text = value,
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                return TextField(
                  key: const Key('split-locality'),
                  controller: controller,
                  focusNode: focus,
                  onChanged: (value) => _locality.text = value,
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'Locality'),
                    prefixIcon: const Icon(Icons.place_outlined),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('split-rent'),
              controller: _rent,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Total rent per month'),
                prefixText: '₹ ',
                prefixIcon: const Icon(Icons.currency_rupee),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.groups_outlined,
                  color: HomiziColors.logoOrange,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    homiziText(context, 'Total people'),
                    style: text.titleSmall,
                  ),
                ),
                IconButton(
                  key: const Key('split-people-minus'),
                  tooltip: homiziText(context, 'Fewer people'),
                  onPressed: _people > 1
                      ? () => setState(() => _people -= 1)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_people',
                  key: const Key('split-people'),
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  key: const Key('split-people-plus'),
                  tooltip: homiziText(context, 'More people'),
                  onPressed: _people < bedroomsFor(_bhk) * maxPeoplePerRoom
                      ? () => setState(() => _people += 1)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: HomiziColors.clear),
              child: ExpansionTile(
                key: const Key('split-bills'),
                tilePadding: EdgeInsets.zero,
                title: Text(
                  homiziText(context, 'Maintenance & utilities (optional)'),
                  style: text.titleSmall,
                ),
                subtitle: Text(
                  homiziText(context, 'Shared equally by everyone.'),
                  style: text.bodySmall?.copyWith(color: HomiziColors.muted),
                ),
                children: [
                  TextField(
                    key: const Key('split-maintenance'),
                    controller: _maintenance,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: homiziText(context, 'Maintenance per month'),
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const Key('split-utilities'),
                    controller: _utilities,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: homiziText(
                        context,
                        'Electricity, Wi-Fi, water per month',
                      ),
                      prefixText: '₹ ',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        homiziText(
          context,
          widget.initialRentInr != null
              ? 'Filled in from your shared home. Check the total rent.'
              : 'Sample values shown. Change them to your home.',
        ),
        style: text.bodySmall?.copyWith(color: HomiziColors.muted),
      ),
      const SizedBox(height: 16),
      _GradientButton(
        buttonKey: const Key('split-start'),
        icon: Icons.calculate_outlined,
        label: 'Calculate rent split',
        onPressed: _toRooms,
      ),
      if (_history.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(
          homiziText(context, 'Your saved splits'),
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        for (final split in _history.take(3))
          Container(
            key: Key('split-history-${split.id}'),
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: HomiziColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.task_alt, color: HomiziColors.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    homiziText(
                      context,
                      '${split.home.bhk}, ${split.home.locality} · ${formatInr(split.home.rentInr)} · ${split.shares.length} people',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ];
  }

  List<Widget> _roomsStep(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return [
      Text(
        homiziText(context, 'Add room & occupancy details'),
        style: _h1(context),
      ),
      const SizedBox(height: 4),
      Text(
        homiziText(
          context,
          'Tap a room to change its size, bathroom, or who stays there.',
        ),
        style: text.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < _rooms.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RoomCard(
            index: i,
            title: roomTitle(_rooms, i),
            room: _rooms[i],
            onEdit: () => unawaited(_editRoom(i)),
            onOccupancy: (count) => _setOccupancy(i, count),
          ),
        ),
      const SizedBox(height: 4),
      _GradientButton(
        buttonKey: const Key('split-calculate'),
        icon: Icons.calculate_outlined,
        label: 'Calculate',
        onPressed: _toResult,
      ),
    ];
  }

  List<Widget> _result(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final outcome = _outcome;
    final ok = outcome.problem == null;
    return [
      Text(homiziText(context, 'Rent split result'), style: _h1(context)),
      const SizedBox(height: 12),
      Container(
        key: const Key('split-total-rent'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HomiziColors.successWash,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, 'Total rent'),
                    style: text.bodyMedium?.copyWith(
                      color: HomiziColors.inkSoft,
                    ),
                  ),
                  Text(
                    '${formatInr(_home.rentInr)} / ${homiziText(context, 'month')}',
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: HomiziColors.ink,
                    ),
                  ),
                  if (_home.billsInr > 0)
                    Text(
                      homiziText(
                        context,
                        '+ ${formatInr(_home.billsInr)} maintenance & utilities',
                      ),
                      style: text.bodySmall?.copyWith(
                        color: HomiziColors.inkSoft,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle,
              color: HomiziColors.success,
              size: 32,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          for (final mode in SplitMode.values) ...[
            Expanded(
              child: _ModeTab(
                mode: mode,
                selected: _mode == mode,
                onTap: () => _setMode(mode),
              ),
            ),
            if (mode != SplitMode.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < outcome.shares.length; i++)
        _PersonRow(
          index: i,
          share: outcome.shares[i],
          roomLabel: _roomLabel(outcome.shares[i].roomIndex),
          custom: _mode == SplitMode.custom ? _custom[i] : null,
          onCustomChanged: () => setState(() => _agreed.clear()),
        ),
      const SizedBox(height: 4),
      Container(
        key: const Key('split-total-check'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: ok ? HomiziColors.successWash : HomiziColors.errorWash,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              ok ? Icons.savings_outlined : Icons.error_outline,
              color: ok ? HomiziColors.success : HomiziColors.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ok
                    ? '${homiziText(context, 'Total')}: ${formatInr(outcome.grandTotal)}'
                    : homiziText(context, outcome.problem!),
                key: const Key('split-total'),
                style: text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: ok ? HomiziColors.ink : HomiziColors.error,
                ),
              ),
            ),
            if (ok) const Icon(Icons.check_circle, color: HomiziColors.success),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const _HowItWorks(),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        key: const Key('split-copy'),
        onPressed: ok ? () => unawaited(_copySummary()) : null,
        icon: const Icon(Icons.copy_outlined),
        label: Text(homiziText(context, 'Copy summary for roommates')),
      ),
      const SizedBox(height: 10),
      _GradientButton(
        buttonKey: const Key('split-review'),
        icon: Icons.how_to_reg_outlined,
        label: 'Review & agree',
        onPressed: ok ? () => _go(SplitStep.review) : null,
      ),
    ];
  }

  String _roomLabel(int index) => roomTitle(_rooms, index);

  List<Widget> _review(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final outcome = _outcome;
    final allAgreed =
        outcome.shares.isNotEmpty && _agreed.length == outcome.shares.length;
    return [
      Text(homiziText(context, 'Review & agree'), style: _h1(context)),
      const SizedBox(height: 4),
      Text(
        homiziText(
          context,
          'Share the summary with your roommates. Tick each person once they say yes. HOMIZI does not message anyone for you.',
        ),
        style: text.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HomiziColors.soft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          splitSummaryText(
            home: _home,
            rooms: _rooms,
            mode: _mode,
            shares: outcome.shares,
          ),
          key: const Key('split-summary'),
          style: text.bodyMedium?.copyWith(height: 1.4),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('split-copy-review'),
          onPressed: () => unawaited(_copySummary()),
          icon: const Icon(Icons.copy_outlined),
          label: Text(homiziText(context, 'Copy summary')),
        ),
      ),
      for (var i = 0; i < outcome.shares.length; i++)
        CheckboxListTile(
          key: Key('split-agree-$i'),
          contentPadding: EdgeInsets.zero,
          activeColor: HomiziColors.success,
          value: _agreed.contains(i),
          onChanged: (value) => setState(() {
            if (value ?? false) {
              _agreed.add(i);
            } else {
              _agreed.remove(i);
            }
          }),
          title: Text(
            homiziText(
              context,
              '${outcome.shares[i].name} agrees to ${formatInr(outcome.shares[i].totalInr)}',
            ),
          ),
          controlAffinity: ListTileControlAffinity.leading,
        ),
      const SizedBox(height: 12),
      _GradientButton(
        buttonKey: const Key('split-finalize'),
        icon: Icons.handshake_outlined,
        label: allAgreed
            ? 'Finalize split'
            : 'Waiting for ${outcome.shares.length - _agreed.length} to agree',
        busy: _busy,
        onPressed: allAgreed && !_busy ? () => unawaited(_finalize()) : null,
      ),
    ];
  }

  List<Widget> _done(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final split = _saved!;
    final mine = split.shares.first;
    final paid = _paid;
    return [
      const SizedBox(height: 20),
      Center(
        child: Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: HomiziColors.successWash,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.task_alt,
            size: 48,
            color: HomiziColors.success,
          ),
        ),
      ),
      const SizedBox(height: 16),
      Text(
        homiziText(context, 'Rent split finalized'),
        key: const Key('split-done'),
        textAlign: TextAlign.center,
        style: _h1(context)?.copyWith(color: HomiziColors.success),
      ),
      const SizedBox(height: 6),
      Text(
        homiziText(
          context,
          '${split.home.bhk}, ${split.home.locality} · ${split.mode.label} · everyone agreed.',
        ),
        textAlign: TextAlign.center,
        style: text.bodyMedium?.copyWith(color: HomiziColors.inkSoft),
      ),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: HomiziColors.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            for (final share in split.shares)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        homiziText(
                          context,
                          '${share.name} · ${roomTitle(split.rooms, share.roomIndex)}',
                        ),
                      ),
                    ),
                    Text(
                      formatInr(share.totalInr),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        homiziText(
          context,
          _savedRemotely
              ? 'Saved to your HOMIZI account.'
              : 'Saved on this device.',
        ),
        key: const Key('split-saved-where'),
        textAlign: TextAlign.center,
        style: text.bodySmall?.copyWith(color: HomiziColors.muted),
      ),
      const SizedBox(height: 20),
      if (paid == null)
        _GradientButton(
          buttonKey: const Key('split-pay'),
          icon: Icons.account_balance_wallet_outlined,
          label: 'Pay my share ${formatInr(mine.totalInr)} (demo)',
          busy: _busy,
          onPressed: _busy ? null : () => unawaited(_payMyShare()),
        )
      else
        Container(
          key: const Key('split-paid'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomiziColors.successWash,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.verified, color: HomiziColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  homiziText(
                    context,
                    'Demo payment of ${formatInr(paid.amountInr)} recorded. No real money moved.',
                  ),
                  style: const TextStyle(
                    color: HomiziColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 10),
      FilledButton(
        key: const Key('split-finish'),
        style: FilledButton.styleFrom(
          backgroundColor: HomiziColors.success,
          foregroundColor: HomiziColors.onSuccess,
          minimumSize: const Size.fromHeight(50),
        ),
        onPressed: () => HomiziBackButton.leave(context),
        child: Text(homiziText(context, 'Done')),
      ),
      const SizedBox(height: 6),
      TextButton(
        key: const Key('split-new'),
        onPressed: _startOver,
        child: Text(homiziText(context, 'Start a new split')),
      ),
    ];
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.step});

  final SplitStep step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Home', 'Rooms', 'Result', 'Agree'];
    final at = step.index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: i <= at
                          ? HomiziColors.logoOrange
                          : HomiziColors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    homiziText(context, labels[i]),
                    style: TextStyle(
                      fontSize: 11,
                      color: i <= at ? HomiziColors.ink : HomiziColors.muted,
                      fontWeight: i == at ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (i < labels.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: HomiziColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: HomiziColors.logoOrange),
                const SizedBox(width: 8),
                Text(
                  homiziText(context, title),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: HomiziColors.brandRedOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.buttonKey,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final Key buttonKey;
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [HomiziColors.logoOrange, HomiziColors.brandRedOrange],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: buttonKey,
            borderRadius: BorderRadius.circular(16),
            onTap: onPressed,
            child: SizedBox(
              height: 52,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: HomiziColors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, color: HomiziColors.white, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              homiziText(context, label),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: HomiziColors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({
    required this.index,
    required this.title,
    required this.room,
    required this.onEdit,
    required this.onOccupancy,
  });

  final int index;
  final String title;
  final SplitRoom room;
  final VoidCallback onEdit;
  final ValueChanged<int> onOccupancy;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = room.occupants.length;
    return Container(
      decoration: BoxDecoration(
        color: room.isMaster ? HomiziColors.accentWash : HomiziColors.white,
        border: Border.all(
          color: room.isMaster ? HomiziColors.brandOrange : HomiziColors.line,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          InkWell(
            key: Key('split-room-$index'),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            onTap: onEdit,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.bed_outlined,
                    color: HomiziColors.logoOrange,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          homiziText(context, title),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: HomiziColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          homiziText(context, room.detail),
                          key: Key('split-room-detail-$index'),
                          style: text.bodyMedium?.copyWith(
                            color: HomiziColors.inkSoft,
                          ),
                        ),
                        if (room.occupants.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              room.occupants.join(' · '),
                              style: text.bodySmall?.copyWith(
                                color: HomiziColors.muted,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: HomiziColors.muted),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(46, 0, 14, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: HomiziColors.logoOrange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  key: Key('split-occupancy-$index'),
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('occupancy-$index-$count'),
                    initialValue: count,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      for (var n = 0; n <= maxPeoplePerRoom; n++)
                        DropdownMenuItem(
                          value: n,
                          child: Text(
                            homiziText(
                              context,
                              n == 0
                                  ? 'Empty'
                                  : n == 1
                                  ? '1 person'
                                  : '$n people',
                            ),
                          ),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        onOccupancy(value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomSheet extends StatefulWidget {
  const _RoomSheet({required this.title, required this.room});

  final String title;
  final SplitRoom room;

  @override
  State<_RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends State<_RoomSheet> {
  late SplitRoomSize _size = widget.room.size;
  late bool _bath = widget.room.attachedBath;
  late bool _balcony = widget.room.balcony;
  late final List<TextEditingController> _names = [
    for (final name in widget.room.occupants) TextEditingController(text: name),
  ];

  @override
  void dispose() {
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, widget.title),
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(homiziText(context, 'Room size'), style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final size in SplitRoomSize.values)
                  ChoiceChip(
                    key: Key('split-size-${size.wire}'),
                    label: Text(homiziText(context, size.label)),
                    selected: _size == size,
                    selectedColor: HomiziColors.accentWash,
                    onSelected: (_) => setState(() => _size = size),
                  ),
              ],
            ),
            SwitchListTile(
              key: const Key('split-bath'),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: HomiziColors.logoOrange,
              value: _bath,
              onChanged: (value) => setState(() => _bath = value),
              title: Text(homiziText(context, 'Attached bathroom')),
            ),
            SwitchListTile(
              key: const Key('split-balcony'),
              contentPadding: EdgeInsets.zero,
              activeThumbColor: HomiziColors.logoOrange,
              value: _balcony,
              onChanged: (value) => setState(() => _balcony = value),
              title: Text(homiziText(context, 'Private balcony')),
            ),
            if (_names.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                homiziText(context, 'Who stays here'),
                style: text.titleSmall,
              ),
              for (var i = 0; i < _names.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    key: Key('split-person-$i'),
                    controller: _names[i],
                    decoration: InputDecoration(
                      labelText: homiziText(context, 'First name'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _GradientButton(
              buttonKey: const Key('split-room-save'),
              label: 'Save room',
              onPressed: () {
                final names = [
                  for (var i = 0; i < _names.length; i++)
                    _names[i].text.trim().isEmpty
                        ? widget.room.occupants[i]
                        : _names[i].text.trim(),
                ];
                Navigator.of(context).pop(
                  widget.room.copyWith(
                    size: _size,
                    attachedBath: _bath,
                    balcony: _balcony,
                    occupants: names,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final SplitMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        key: Key('split-mode-${mode.wire}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      HomiziColors.logoOrange,
                      HomiziColors.brandRedOrange,
                    ],
                  )
                : null,
            color: selected ? null : HomiziColors.white,
            border: Border.all(
              color: selected ? HomiziColors.logoOrange : HomiziColors.line,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                homiziText(context, mode.label),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: selected ? HomiziColors.white : HomiziColors.ink,
                ),
              ),
              Text(
                homiziText(context, mode.hint),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected ? HomiziColors.white : HomiziColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.index,
    required this.share,
    required this.roomLabel,
    required this.custom,
    required this.onCustomChanged,
  });

  final int index;
  final PersonShare share;
  final String roomLabel;
  final TextEditingController? custom;
  final VoidCallback onCustomChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final initial = share.name.trim().isEmpty
        ? '?'
        : share.name.trim().characters.first.toUpperCase();
    return Container(
      key: Key('split-person-row-$index'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: index == 0 ? HomiziColors.accentWash : HomiziColors.white,
        border: Border.all(color: HomiziColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: index == 0
                ? HomiziColors.logoOrange
                : HomiziColors.soft,
            child: Text(
              initial,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: index == 0 ? HomiziColors.white : HomiziColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  share.name,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  homiziText(context, roomLabel),
                  style: text.bodySmall?.copyWith(color: HomiziColors.muted),
                ),
                if (share.billsInr > 0)
                  Text(
                    homiziText(
                      context,
                      'Rent ${formatInr(share.rentInr)} + bills ${formatInr(share.billsInr)}',
                    ),
                    style: text.bodySmall?.copyWith(
                      color: HomiziColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
          if (custom != null)
            SizedBox(
              width: 110,
              child: TextField(
                key: Key('split-custom-$index'),
                controller: custom,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.end,
                onChanged: (_) => onCustomChanged(),
                decoration: const InputDecoration(
                  isDense: true,
                  prefixText: '₹ ',
                ),
              ),
            )
          else
            Text(
              formatInr(share.totalInr),
              key: Key('split-amount-$index'),
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: HomiziColors.ink,
              ),
            ),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const points = <(IconData, String)>[
      (
        Icons.bed_outlined,
        'Considers room size (larger vs standard vs smaller).',
      ),
      (
        Icons.shower_outlined,
        'Adds weight for an attached bathroom or private balcony.',
      ),
      (
        Icons.groups_outlined,
        'Splits a room’s share between the people in it.',
      ),
      (Icons.tune, 'You can switch to an equal split or set a custom split.'),
      (Icons.edit_note, 'Everyone reviews and agrees before it is final.'),
    ];
    return Container(
      key: const Key('split-how'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: HomiziColors.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            homiziText(context, 'How the split works'),
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: HomiziColors.brandRedOrange,
            ),
          ),
          const SizedBox(height: 8),
          for (final (icon, line) in points)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: HomiziColors.logoOrange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(homiziText(context, line))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// `/tools/split?with=Amit,Rahul` prefills roommates. Up to 11 first names.
List<String> splitRoommatesFromQuery(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const [];
  }
  return [
    for (final part in raw.split(','))
      if (part.trim().isNotEmpty) part.trim().split(' ').first,
  ].take(11).toList();
}
