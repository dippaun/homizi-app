import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/broker/broker_page.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/chat/thread_providers.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/owner/owner_gateway.dart';
import 'package:homizi/features/owner/owner_providers.dart';
import 'package:homizi/features/owner/owner_rules.dart';

class BrokerVisitNote {
  const BrokerVisitNote({
    required this.id,
    required this.seeker,
    required this.place,
    required this.whenLabel,
    required this.status,
  });

  final String id;
  final String seeker;
  final String place;
  final String whenLabel;
  final String status;

  BrokerVisitNote copyWith({String? status}) {
    return BrokerVisitNote(
      id: id,
      seeker: seeker,
      place: place,
      whenLabel: whenLabel,
      status: status ?? this.status,
    );
  }
}

class _VisitRow {
  const _VisitRow({
    required this.id,
    required this.seeker,
    required this.place,
    required this.detail,
    required this.status,
    required this.leadId,
  });

  final String id;
  final String seeker;
  final String place;
  final String detail;
  final String status;
  final String? leadId;
}

class BrokerVisitNotes extends Notifier<List<BrokerVisitNote>> {
  @override
  List<BrokerVisitNote> build() => const [];

  void add(BrokerVisitNote note) {
    state = [note, ...state];
  }

  void confirm(String id) {
    state = [
      for (final note in state)
        if (note.id == id) note.copyWith(status: 'Confirmed') else note,
    ];
  }
}

final brokerVisitNotesProvider =
    NotifierProvider<BrokerVisitNotes, List<BrokerVisitNote>>(
      BrokerVisitNotes.new,
    );

class BrokerVisitsScreen extends ConsumerStatefulWidget {
  const BrokerVisitsScreen({super.key});

  @override
  ConsumerState<BrokerVisitsScreen> createState() => _BrokerVisitsScreenState();
}

class _BrokerVisitsScreenState extends ConsumerState<BrokerVisitsScreen> {
  final _seeker = TextEditingController(text: 'Meera Krishnan');
  final _place = TextEditingController(text: 'Koramangala, Bengaluru');
  final _when = TextEditingController(text: 'Saturday 11:00');
  List<_VisitRow> _leads = const [];
  var _loading = true;
  var _busy = false;
  String? _note;
  var _appliedQuery = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedQuery) {
      return;
    }
    _appliedQuery = true;
    final seeker = GoRouterState.of(context).uri.queryParameters['seeker'];
    if (seeker != null && seeker.trim().isNotEmpty) {
      _seeker.text = seeker.trim();
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _seeker.dispose();
    _place.dispose();
    _when.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final gateway = ref.read(ownerGatewayProvider);
      final listings = await gateway.myListings();
      final rows = <_VisitRow>[];
      for (final listing in listings) {
        final leads = await gateway.leads(listing.id);
        for (final lead in leads) {
          if (lead.kind != 'visit') {
            continue;
          }
          rows.add(
            _VisitRow(
              id: lead.id,
              seeker: lead.nameLabel,
              place: listing.place,
              detail: listing.title,
              status: ownerLeadStatusLabel(lead.status),
              leadId: lead.id,
            ),
          );
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _leads = rows;
        _loading = false;
      });
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _note = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _schedule() async {
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Visit booked',
        detail: 'A time is saved. The street address stays hidden.',
      );
      return;
    }
    final seeker = _seeker.text.trim();
    final place = _place.text.trim();
    final when = _when.text.trim();
    if (seeker.length < 2 || place.length < 2 || when.isEmpty) {
      setState(() => _note = 'Add a seeker, a place, and a time.');
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
    });
    final id = 'scheduled-${DateTime.now().microsecondsSinceEpoch}';
    final note = BrokerVisitNote(
      id: id,
      seeker: seeker,
      place: place,
      whenLabel: when,
      status: 'Requested',
    );
    try {
      await ref
          .read(threadGatewayProvider)
          .requestVisit('broker-desk', defaultVisitSlots(DateTime.now()));
    } on Object {
      // The desk note still records the time the broker chose.
    }
    if (!mounted) {
      return;
    }
    ref.read(brokerVisitNotesProvider.notifier).add(note);
    setState(() {
      _busy = false;
      _note = 'Visit requested for $seeker.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(brokerVisitNotesProvider);
    return Scaffold(
      key: const Key('broker-visits-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Visits')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'A visit is a time and a locality. The street address stays hidden until the visit is accepted.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('broker-visit-seeker'),
            controller: _seeker,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Seeker'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('broker-visit-place'),
            controller: _place,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Locality'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('broker-visit-when'),
            controller: _when,
            decoration: InputDecoration(labelText: homiziText(context, 'Time')),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('broker-schedule-visit'),
            onPressed: _busy ? null : () => unawaited(_schedule()),
            child: Text(homiziText(context, 'Schedule a visit')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(
              homiziText(context, _note!),
              key: const Key('broker-visit-note'),
            ),
          ],
          const SizedBox(height: 20),
          if (_loading) const LinearProgressIndicator(),
          for (final note in notes)
            BrokerTapCard(
              cardKey: Key('broker-visit-card-${note.id}'),
              onTap: () => context.push(RoutePaths.brokerVisit(note.id)),
              child: _VisitSummary(
                seeker: note.seeker,
                place: note.place,
                detail: note.whenLabel,
                status: note.status,
              ),
            ),
          for (final row in _leads)
            BrokerTapCard(
              cardKey: Key('broker-visit-card-${row.id}'),
              onTap: () => context.push(RoutePaths.brokerVisit(row.id)),
              child: _VisitSummary(
                seeker: row.seeker,
                place: row.place,
                detail: row.detail,
                status: row.status,
              ),
            ),
          if (!_loading && notes.isEmpty && _leads.isEmpty)
            Text(
              homiziText(context, 'No visit requested yet.'),
              key: const Key('broker-visits-empty'),
            ),
        ],
      ),
    );
  }
}

class BrokerVisitScreen extends ConsumerStatefulWidget {
  const BrokerVisitScreen({required this.visitId, super.key});

  final String visitId;

  @override
  ConsumerState<BrokerVisitScreen> createState() => _BrokerVisitScreenState();
}

class _BrokerVisitScreenState extends ConsumerState<BrokerVisitScreen> {
  _VisitRow? _row;
  var _loading = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final notes = ref.read(brokerVisitNotesProvider);
    for (final note in notes) {
      if (note.id == widget.visitId) {
        setState(() {
          _row = _VisitRow(
            id: note.id,
            seeker: note.seeker,
            place: note.place,
            detail: note.whenLabel,
            status: note.status,
            leadId: null,
          );
          _loading = false;
        });
        return;
      }
    }
    try {
      final gateway = ref.read(ownerGatewayProvider);
      final listings = await gateway.myListings();
      _VisitRow? found;
      for (final listing in listings) {
        final leads = await gateway.leads(listing.id);
        for (final lead in leads) {
          if (lead.id == widget.visitId && lead.kind == 'visit') {
            found = _VisitRow(
              id: lead.id,
              seeker: lead.nameLabel,
              place: listing.place,
              detail: listing.title,
              status: ownerLeadStatusLabel(lead.status),
              leadId: lead.id,
            );
            break;
          }
        }
        if (found != null) {
          break;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _row = found;
        _loading = false;
        _error = found == null ? 'This visit is not on your desk.' : null;
      });
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  Future<void> _confirm() async {
    if (demoModeOn(ref)) {
      openDemoSuccess(
        context,
        title: 'Visit booked',
        detail: 'A time is saved. The street address stays hidden.',
      );
      return;
    }
    final row = _row;
    if (row == null) {
      return;
    }
    setState(() => _busy = true);
    final leadId = row.leadId;
    if (leadId == null) {
      ref.read(brokerVisitNotesProvider.notifier).confirm(row.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _row = _VisitRow(
          id: row.id,
          seeker: row.seeker,
          place: row.place,
          detail: row.detail,
          status: 'Confirmed',
          leadId: null,
        );
      });
      return;
    }
    try {
      final updated = await ref
          .read(ownerGatewayProvider)
          .setLeadStatus(leadId, 'replied');
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _row = _VisitRow(
          id: row.id,
          seeker: row.seeker,
          place: row.place,
          detail: row.detail,
          status: ownerLeadStatusLabel(updated.status),
          leadId: leadId,
        );
      });
    } on OwnerFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        key: Key('broker-visit-screen'),
        backgroundColor: HomiziColors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final row = _row;
    if (row == null) {
      return BrokerPage(
        screenKey: const Key('broker-visit-screen'),
        title: 'Visit',
        children: [
          Text(
            homiziText(context, _error ?? 'This visit is not on your desk.'),
          ),
        ],
      );
    }
    return BrokerPage(
      screenKey: const Key('broker-visit-screen'),
      title: 'Visit',
      children: [
        _VisitSummary(
          seeker: row.seeker,
          place: row.place,
          detail: row.detail,
          status: row.status,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(homiziText(context, _error!)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('broker-visit-confirm'),
          onPressed: _busy ? null : () => unawaited(_confirm()),
          child: Text(homiziText(context, 'Confirm visit')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('broker-visit-chat'),
          onPressed: () => context.push(
            RoutePaths.chat(
              'broker-visit-${row.id}',
              name: row.seeker,
              title: row.place,
            ),
          ),
          child: Text(homiziText(context, 'Open chat')),
        ),
      ],
    );
  }
}

class _VisitSummary extends StatelessWidget {
  const _VisitSummary({
    required this.seeker,
    required this.place,
    required this.detail,
    required this.status,
  });

  final String seeker;
  final String place;
  final String detail;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, seeker),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(homiziText(context, place)),
        const SizedBox(height: 4),
        Text(homiziText(context, detail)),
        const SizedBox(height: 4),
        Text(
          homiziText(context, status),
          key: const Key('broker-visit-status'),
        ),
      ],
    );
  }
}
