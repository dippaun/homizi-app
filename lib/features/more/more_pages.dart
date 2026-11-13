import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/more/more_requests.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/services/service_providers.dart';

class ServiceInfoScreen extends ConsumerStatefulWidget {
  const ServiceInfoScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<ServiceInfoScreen> createState() => _ServiceInfoScreenState();
}

class _ServiceInfoScreenState extends ConsumerState<ServiceInfoScreen> {
  final _locality = TextEditingController();
  final _note = TextEditingController();
  var _city = personalCities.first;
  var _consent = false;
  var _busy = false;
  String? _error;
  var _saved = false;

  @override
  void dispose() {
    _locality.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _title => moreRequestLabel(widget.id);

  String get _body {
    return switch (widget.id) {
      'appliance' =>
        'A HOMIZI partner can visit for a washing machine, fridge, or mixer. This page does not quote a visit fee.',
      'pest' =>
        'A HOMIZI partner can visit for pests in the home. This page does not quote a treatment fee.',
      'residential' =>
        'Tell us about a home you want help with. A partner confirms the scope. This page does not quote a plan fee.',
      'commercial' =>
        'Tell us about a shop, office, or other workspace. A partner confirms the scope. This page does not quote a plan fee.',
      _ =>
        'Tell HOMIZI what you need. A partner confirms the scope. This page does not quote a fee.',
    };
  }

  Future<void> _submit() async {
    final locality = _locality.text.trim();
    if (locality.length < 2) {
      setState(() => _error = 'Enter the locality.');
      return;
    }
    if (!_consent) {
      setState(() => _error = 'Confirm that a HOMIZI partner may contact you.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(moreRequestProvider.notifier)
          .add(
            kind: widget.id,
            city: _city,
            locality: locality,
            note: _note.text,
          );
      if (mounted) {
        setState(() {
          _busy = false;
          _saved = true;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'The request was not saved. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: Key('service-info-${widget.id}'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, _title)),
      ),
      body: _saved
          ? _Confirm(title: _title)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Text(homiziText(context, _body)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: const Key('service-info-city'),
                  initialValue: _city,
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'City'),
                  ),
                  items: [
                    for (final city in personalCities)
                      DropdownMenuItem(value: city, child: Text(city)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _city = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('service-info-locality'),
                  controller: _locality,
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'Locality'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('service-info-note'),
                  controller: _note,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: homiziText(context, 'What do you need?'),
                  ),
                ),
                CheckboxListTile(
                  key: const Key('service-info-consent'),
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: (value) =>
                      setState(() => _consent = value ?? false),
                  title: Text(
                    homiziText(
                      context,
                      'A HOMIZI partner may contact me about this request.',
                    ),
                  ),
                ),
                if (_error != null)
                  Text(
                    key: const Key('service-info-error'),
                    homiziText(context, _error!),
                    style: const TextStyle(color: HomiziColors.error),
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('service-info-submit'),
                  onPressed: _busy ? null : () => unawaited(_submit()),
                  child: Text(
                    homiziText(context, _busy ? 'Sending…' : 'Send request'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Confirm extends StatelessWidget {
  const _Confirm({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('service-info-saved'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        const Icon(Icons.check_circle, color: HomiziColors.success, size: 48),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Request sent'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: HomiziColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'Your $title request is saved on this device. A partner confirms the scope. No fee was quoted.',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go(RoutePaths.more),
          child: Text(homiziText(context, 'Back to More')),
        ),
      ],
    );
  }
}

class MyServicesScreen extends ConsumerWidget {
  const MyServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(moreRequestProvider);
    final remote = ref.watch(_myLeadsProvider);
    return Scaffold(
      key: const Key('my-services-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'My Services')),
      ),
      body: remote.when(
        loading: () => const LoadingState(message: 'Loading your requests…'),
        error: (error, stack) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            SizedBox(
              height: 280,
              child: ErrorState(
                title: 'Could not load partner requests',
                message:
                    'Requests saved on this device are still listed below.',
                onRetry: () => ref.invalidate(_myLeadsProvider),
              ),
            ),
            for (final row in local)
              ListTile(
                key: Key('my-service-${row.id}'),
                title: Text(homiziText(context, moreRequestLabel(row.kind))),
                subtitle: Text('${row.locality}, ${row.city}'),
              ),
            if (local.isEmpty)
              const EmptyState(
                title: 'No on-device requests',
                message: 'Nothing saved on this device yet.',
              ),
          ],
        ),
        data: (leads) {
          if (leads.isEmpty && local.isEmpty) {
            return EmptyState(
              title: 'No requests yet',
              message:
                  'Painting, cleaning, and the other services you ask for show up here.',
              actionLabel: 'Browse services',
              onAction: () => context.go(RoutePaths.more),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final row in local)
                ListTile(
                  key: Key('my-service-${row.id}'),
                  title: Text(homiziText(context, moreRequestLabel(row.kind))),
                  subtitle: Text('${row.locality}, ${row.city}'),
                ),
              for (final lead in leads)
                ListTile(
                  title: Text(homiziText(context, lead.kind.label)),
                  subtitle: Text(
                    '${lead.fromLocality}, ${lead.city} · ${lead.statusLabel}',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

final _myLeadsProvider = FutureProvider<List<ServiceLead>>((ref) async {
  return ref.watch(serviceLeadGatewayProvider).listMine();
});

class AboutHomiziScreen extends StatelessWidget {
  const AboutHomiziScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('about-homizi'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'About Homizi')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            homiziText(context, 'Find a place. Find your people.'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'HOMIZI is for people in India who want to rent a home, find a flatmate, or list a property. Rent smarter, live better.',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(
              context,
              'Identity checks run through Digio when that service is live. This page does not verify anyone and does not take a payment.',
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.push(RoutePaths.privacy),
            child: Text(homiziText(context, 'Privacy')),
          ),
          TextButton(
            onPressed: () => context.push(RoutePaths.terms),
            child: Text(homiziText(context, 'Terms')),
          ),
          TextButton(
            onPressed: () => context.push(RoutePaths.help),
            child: Text(homiziText(context, 'Help & Support')),
          ),
        ],
      ),
    );
  }
}
