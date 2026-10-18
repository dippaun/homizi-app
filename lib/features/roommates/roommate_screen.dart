import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/core/format/ordered_range.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/range_field.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/interest/swipe_deck.dart';
import 'package:homizi/features/roommates/compatibility_sheet.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:homizi/features/roommates/roommate_card.dart';
import 'package:homizi/features/roommates/roommate_gateway.dart';
import 'package:homizi/features/roommates/roommate_providers.dart';

class RoommateScreen extends ConsumerStatefulWidget {
  const RoommateScreen({super.key});

  @override
  ConsumerState<RoommateScreen> createState() => _RoommateScreenState();
}

class _RoommateScreenState extends ConsumerState<RoommateScreen> {
  var _query = const RoommateQuery();
  var _rows = const <RoommateSeeker>[];
  var _loading = true;
  String? _error;
  var _swipe = false;
  var _index = 0;
  var _dx = 0.0;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ref.read(roommateGatewayProvider).load(_query);
      if (!mounted) {
        return;
      }
      setState(() {
        _rows = rows;
        _loading = false;
        _index = 0;
        _dx = 0;
      });
    } on RoommateFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _openScore(RoommateSeeker seeker) async {
    try {
      final score = await ref.read(roommateGatewayProvider).breakdown(seeker);
      if (!mounted) {
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: HomiziColors.white,
        builder: (context) =>
            RoommateBreakdownSheet(seeker: seeker, score: score),
      );
    } on RoommateFailure catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(homiziText(context, error.message))));
    }
  }

  Future<void> _openFilters() async {
    final next = await showModalBottomSheet<RoommateQuery>(
      context: context,
      isScrollControlled: true,
      backgroundColor: HomiziColors.white,
      builder: (context) => _FilterSheet(initial: _query),
    );
    if (next == null || !mounted) {
      return;
    }
    setState(() => _query = next);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('roommate-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: const ScreenTitle('Roommates'),
        actions: [
          IconButton(
            key: const Key('roommate-filters'),
            tooltip: homiziText(context, 'Filters'),
            onPressed: _openFilters,
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            key: const Key('roommate-show-swipe'),
            tooltip: homiziText(context, _swipe ? 'List' : 'Swipe'),
            onPressed: () => setState(() {
              _swipe = !_swipe;
              _dx = 0;
            }),
            icon: Icon(_swipe ? Icons.view_agenda_outlined : Icons.style_outlined),
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) {
      return const LoadingState(message: 'Finding roommates…');
    }
    if (_error != null) {
      return ErrorState(
        title: 'Roommates did not load',
        message: _error!,
        onRetry: _load,
      );
    }
    if (_rows.isEmpty) {
      return const EmptyState(
        title: 'No roommates match',
        message: 'Try a wider budget or clear the filters.',
      );
    }
    if (_swipe) {
      return _swipeBody();
    }
    return ListView.separated(
      key: const Key('roommate-list'),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      itemCount: _rows.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final seeker = _rows[index];
        return RoommateCard(seeker: seeker, onScore: () => _openScore(seeker));
      },
    );
  }

  Widget _swipeBody() {
    if (_index >= _rows.length) {
      return const EmptyState(
        title: 'You are caught up',
        message: 'Likes wait for a mutual match. Contact stays hidden.',
      );
    }
    final seeker = _rows[_index];
    return SwipeDeck(
      dx: _dx,
      busy: _busy,
      note: null,
      canUndo: false,
      showUndo: false,
      likeLabel: 'Interested in ${seeker.name}',
      passLabel: 'Pass on ${seeker.name}',
      cardKey: const Key('roommate-swipe-card'),
      onDrag: (delta) => setState(() => _dx += delta),
      onRelease: () {
        final pass = _dx < -90;
        final like = _dx > 90;
        setState(() => _dx = 0);
        if (pass || like) {
          unawaited(_act(seeker, pass: pass));
        }
      },
      onLike: () => unawaited(_act(seeker, pass: false)),
      onPass: () => unawaited(_act(seeker, pass: true)),
      onUndo: () {},
      card: RoommateSwipeCard(
        seeker: seeker,
        dx: _dx,
        onScore: () => _openScore(seeker),
      ),
    );
  }

  Future<void> _act(RoommateSeeker seeker, {required bool pass}) async {
    setState(() => _busy = true);
    try {
      final gateway = ref.read(roommateGatewayProvider);
      final message = pass
          ? await gateway.pass(seeker)
          : await gateway.like(seeker);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _dx = 0;
        _index += 1;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(homiziText(context, message))));
    } on RoommateFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _dx = 0;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(homiziText(context, error.message))));
    }
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final RoommateQuery initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final TextEditingController _locality;
  late int _budgetMin;
  late int _budgetMax;
  late String _gender;
  late String _moveIn;

  @override
  void initState() {
    super.initState();
    _locality = TextEditingController(text: widget.initial.locality);
    _budgetMin = widget.initial.budgetMinInr;
    _budgetMax = widget.initial.budgetMaxInr;
    _gender = widget.initial.gender;
    _moveIn = widget.initial.moveInWindow;
  }

  @override
  void dispose() {
    _locality.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottom),
      child: SingleChildScrollView(
        key: const Key('roommate-filter-sheet'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, 'Filters'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('roommate-locality'),
              controller: _locality,
              decoration: InputDecoration(
                labelText: homiziText(context, 'Locality'),
              ),
            ),
            const SizedBox(height: 16),
            HomiziRangeField(
              label: 'Budget',
              min: InrRangeScale.min,
              max: InrRangeScale.max,
              step: InrRangeScale.step,
              start: _budgetMin,
              end: _budgetMax,
              formatValue: formatInr,
              openAtBounds: true,
              minSemantics: 'Budget minimum (INR)',
              maxSemantics: 'Budget maximum (INR)',
              onChanged: (start, end) => setState(() {
                _budgetMin = start;
                _budgetMax = end;
              }),
            ),
            const SizedBox(height: 16),
            Text(
              homiziText(context, 'Gender'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final choice in const [
                  ('any', 'Any'),
                  ('woman', 'Women'),
                  ('man', 'Men'),
                ])
                  FilterChip(
                    key: Key('roommate-gender-${choice.$1}'),
                    label: Text(homiziText(context, choice.$2)),
                    selected: _gender == choice.$1,
                    onSelected: (_) => setState(() => _gender = choice.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              homiziText(context, 'Move-in'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final choice in const [
                  ('any', 'Any'),
                  ('30', '30 days'),
                  ('60', '60 days'),
                  ('flexible', 'Flexible'),
                ])
                  FilterChip(
                    key: Key('roommate-movein-${choice.$1}'),
                    label: Text(homiziText(context, choice.$2)),
                    selected: _moveIn == choice.$1,
                    onSelected: (_) => setState(() => _moveIn = choice.$1),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('roommate-apply-filters'),
              onPressed: () {
                Navigator.pop(
                  context,
                  RoommateQuery(
                    locality: _locality.text.trim(),
                    budgetMinInr: _budgetMin,
                    budgetMaxInr: _budgetMax,
                    gender: _gender,
                    moveInWindow: _moveIn,
                  ),
                );
              },
              child: Text(homiziText(context, 'Show people')),
            ),
          ],
        ),
      ),
    );
  }
}
