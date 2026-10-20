import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/services/service_lead_gateway.dart';
import 'package:homizi/features/services/service_providers.dart';

class ServiceRequestScreen extends ConsumerStatefulWidget {
  const ServiceRequestScreen({required this.kind, super.key});

  final ServiceKind kind;

  @override
  ConsumerState<ServiceRequestScreen> createState() =>
      _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends ConsumerState<ServiceRequestScreen> {
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _notes = TextEditingController();
  String _city = serviceCities.first;
  String _size = homeSizes[2];
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  var _consent = false;
  var _busy = false;
  String? _note;
  List<ServiceLead> _rows = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await ref.read(serviceLeadGatewayProvider).listMine();
    if (mounted) {
      setState(() => _rows = rows);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _date,
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    final draft = ServiceLeadDraft(
      kind: widget.kind,
      fromLocality: _from.text,
      toLocality: widget.kind.asksForDestination ? _to.text : null,
      city: _city,
      requestedOn: _date,
      homeSize: _size,
      notes: _notes.text,
      contactConsent: _consent,
    );
    final problem = validateServiceLead(draft);
    if (problem != null) {
      if (demoModeOn(ref)) {
        openDemoSuccess(
          context,
          title: 'Request sent',
          detail: 'A partner can see this request in the demo.',
        );
        return;
      }
      setState(() => _note = problem);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(serviceLeadGatewayProvider).submit(draft);
      if (!mounted) {
        return;
      }
      if (demoModeOn(ref)) {
        setState(() => _busy = false);
        openDemoSuccess(
          context,
          title: 'Request sent',
          detail: 'A partner can see this request in the demo.',
        );
        return;
      }
      setState(
        () => _note =
            'Request sent. A HOMIZI partner will contact you. This is not a confirmed booking.',
      );
      await _load();
    } on ServiceLeadFailure catch (error) {
      if (mounted) {
        setState(() => _note = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final day =
        '${_date.day.toString().padLeft(2, '0')} ${_month(_date.month)} ${_date.year}';
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, widget.kind.label)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'A HOMIZI partner will contact you. This request is not a confirmed booking.',
            ),
          ),
          const SizedBox(height: 12),
          DropdownMenu<String>(
            initialSelection: _city,
            label: Text(homiziText(context, 'City')),
            dropdownMenuEntries: [
              for (final city in serviceCities)
                DropdownMenuEntry(value: city, label: city),
            ],
            onSelected: (value) {
              if (value != null) {
                setState(() => _city = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('service-from'),
            controller: _from,
            decoration: InputDecoration(
              labelText: homiziText(context, 'From locality'),
            ),
          ),
          if (widget.kind.asksForDestination) ...[
            const SizedBox(height: 12),
            TextField(
              key: const Key('service-to'),
              controller: _to,
              decoration: InputDecoration(
                labelText: homiziText(context, 'To locality'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(homiziText(context, 'Date')),
            subtitle: Text(day),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () => unawaited(_pickDate()),
          ),
          DropdownMenu<String>(
            initialSelection: _size,
            label: Text(homiziText(context, 'Home size')),
            dropdownMenuEntries: [
              for (final size in homeSizes)
                DropdownMenuEntry(value: size, label: size),
            ],
            onSelected: (value) {
              if (value != null) {
                setState(() => _size = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Notes'),
            ),
          ),
          CheckboxListTile(
            key: const Key('service-consent'),
            contentPadding: EdgeInsets.zero,
            value: _consent,
            onChanged: (value) => setState(() => _consent = value ?? false),
            title: Text(
              homiziText(
                context,
                'I agree that a HOMIZI partner may contact me about this request.',
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton(
            key: const Key('service-submit'),
            onPressed: _busy ? null : () => unawaited(_submit()),
            child: Text(homiziText(context, 'Send request')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(homiziText(context, _note!), key: const Key('service-note')),
          ],
          const SizedBox(height: 24),
          Text(
            homiziText(context, 'Your requests'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_rows.isEmpty) Text(homiziText(context, 'No requests yet.')),
          for (final lead in _rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(homiziText(context, lead.kind.label)),
              subtitle: Text('${lead.fromLocality}, ${lead.city}'),
              trailing: Text(homiziText(context, lead.statusLabel)),
            ),
        ],
      ),
    );
  }

  String _month(int month) {
    return const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month - 1];
  }
}
