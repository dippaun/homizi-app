import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_auth.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/broker/broker_profile.dart';
import 'package:homizi/features/broker/broker_providers.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class BrokerRegistrationScreen extends ConsumerStatefulWidget {
  const BrokerRegistrationScreen({super.key});

  @override
  ConsumerState<BrokerRegistrationScreen> createState() =>
      _BrokerRegistrationScreenState();
}

class _BrokerRegistrationScreenState
    extends ConsumerState<BrokerRegistrationScreen> {
  final _name = TextEditingController();
  final _agency = TextEditingController();
  final _rera = TextEditingController();
  final _locality = TextEditingController();
  final _phone = TextEditingController();
  final _cities = <String>{};
  final _localities = <String>[];
  var _years = 3;
  var _loading = true;
  var _busy = false;
  var _saved = false;
  List<String> _errors = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_ensureBrokerRole());
  }

  Future<void> _ensureBrokerRole() async {
    final session = ref.read(sessionProvider);
    if (session.phase != SessionPhase.needsRole &&
        session.phase != SessionPhase.ready) {
      return;
    }
    if (session.homiziWire == 'broker') {
      return;
    }
    await ref.read(sessionProvider.notifier).selectPrimaryRole('broker');
  }

  Future<void> _back() async {
    await _ensureBrokerRole();
    if (!mounted) {
      return;
    }
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    final back = GoRouterState.of(context).uri.queryParameters['back'];
    final target = back != null && back.startsWith('/') && !back.contains('..')
        ? back.split('?').first
        : RoutePaths.home;
    router.go(target);
  }

  @override
  void dispose() {
    _name.dispose();
    _agency.dispose();
    _rera.dispose();
    _locality.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final loaded = await ref.read(brokerGatewayProvider).load();
      if (loaded != null && mounted) {
        _name.text = loaded.fullName;
        _agency.text = loaded.agencyName;
        _rera.text = loaded.reraNumber;
        _phone.text = loaded.phone;
        _cities.addAll(loaded.cities);
        _localities.addAll(loaded.localities);
        _years = loaded.yearsExperience;
        _saved = loaded.fullName.trim().isNotEmpty;
      }
    } on BrokerFailure {
      // A missing row is a new registration.
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  BrokerProfileDraft _draft() {
    final pending = _locality.text.trim();
    return BrokerProfileDraft(
      fullName: _name.text,
      agencyName: _agency.text,
      reraNumber: _rera.text,
      cities: _cities.toList(),
      localities: [
        ..._localities,
        if (pending.isNotEmpty && !_localities.contains(pending)) pending,
      ],
      phone: _phone.text,
      yearsExperience: _years,
    );
  }

  Future<void> _save() async {
    final pending = _locality.text.trim();
    if (pending.isNotEmpty && !_localities.contains(pending)) {
      _localities.add(pending);
      _locality.clear();
    }
    final draft = _draft();
    final issues = draft.errors();
    if (issues.isNotEmpty) {
      setState(() => _errors = issues);
      return;
    }
    setState(() {
      _busy = true;
      _errors = const [];
    });
    try {
      await ref.read(brokerGatewayProvider).save(draft);
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _saved = true;
      });
    } on BrokerFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _errors = [error.message];
      });
    }
  }

  void _open(String path) {
    if (GoRouter.maybeOf(context) != null) {
      context.go(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: HomiziColors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final phase = ref.watch(sessionProvider).phase;
    final signedOut =
        phase == SessionPhase.signedOut || phase == SessionPhase.booting;
    return Scaffold(
      key: const Key('broker-registration-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(title: Text(homiziText(context, 'Broker registration'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          const BrokerChip(),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Tell seekers who you are.'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'You can list homes you manage and see briefs from people who opted in.',
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const Key('broker-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Your name'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('broker-agency'),
            controller: _agency,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Agency name'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('broker-rera'),
            controller: _rera,
            decoration: InputDecoration(
              labelText: homiziText(context, 'RERA registration number'),
              helperText: homiziText(
                context,
                'Optional. Example: PRM/KA/RERA/1251/446/AG/171018/000441',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(homiziText(context, 'Cities you cover')),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final city in exploreCities)
                FilterChip(
                  key: Key('broker-city-$city'),
                  label: Text(homiziText(context, city)),
                  selected: _cities.contains(city),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _cities.add(city);
                    } else {
                      _cities.remove(city);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('broker-locality'),
            controller: _locality,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Locality'),
              hintText: homiziText(context, 'Koramangala'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              final next = _locality.text.trim();
              if (next.isEmpty || _localities.contains(next)) {
                return;
              }
              setState(() {
                _localities.add(next);
                _locality.clear();
              });
            },
            child: Text(homiziText(context, 'Add locality')),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final name in _localities)
                InputChip(
                  label: Text(homiziText(context, name)),
                  onDeleted: () => setState(() => _localities.remove(name)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('broker-phone'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Mobile number'),
              hintText: homiziText(context, '9876543210'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            homiziText(context, 'Years of experience: $_years'),
            key: const Key('broker-years-label'),
          ),
          Slider(
            key: const Key('broker-years'),
            value: _years.toDouble(),
            max: 40,
            divisions: 40,
            label: '$_years',
            onChanged: (value) => setState(() => _years = value.round()),
          ),
          for (final error in _errors)
            Text(
              homiziText(context, error),
              key: Key('broker-error-$error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('broker-save'),
            onPressed: _busy ? null : () => unawaited(_save()),
            child: Text(homiziText(context, _busy ? 'Saving…' : 'Save')),
          ),
          TextButton(
            key: const Key('broker-profile-back'),
            onPressed: () => unawaited(_back()),
            child: Text(homiziText(context, 'Back')),
          ),
          if (signedOut)
            TextButton(
              key: const Key('broker-create-profile'),
              onPressed: () => _open(brokerProfileSignInLocation()),
              child: Text(homiziText(context, 'Create profile')),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                key: const Key('broker-open-home'),
                onPressed: () => _open(RoutePaths.home),
                child: Text(homiziText(context, 'Broker home')),
              ),
              TextButton(
                key: const Key('broker-open-briefs'),
                onPressed: () => _open(RoutePaths.seekers),
                child: Text(homiziText(context, 'Requirement briefs')),
              ),
              TextButton(
                key: const Key('broker-open-listings'),
                onPressed: () => _open(RoutePaths.listings),
                child: Text(homiziText(context, 'Listings')),
              ),
              TextButton(
                key: const Key('broker-open-leads'),
                onPressed: () => _open(RoutePaths.brokerLeads),
                child: Text(homiziText(context, 'Leads')),
              ),
              TextButton(
                key: const Key('broker-open-chats'),
                onPressed: () => _open(RoutePaths.brokerChats),
                child: Text(homiziText(context, 'Chats')),
              ),
              TextButton(
                key: const Key('broker-open-visits'),
                onPressed: () => _open(RoutePaths.brokerVisits),
                child: Text(homiziText(context, 'Visits')),
              ),
            ],
          ),
          if (_saved) ...[
            const SizedBox(height: 20),
            Text(
              homiziText(context, 'Your broker profile is saved.'),
              key: const Key('broker-saved'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('broker-see-seekers'),
              onPressed: () => _open(RoutePaths.brokerSeekers),
              child: Text(homiziText(context, 'Matching seekers')),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('broker-post-listing'),
              onPressed: () => _open('${RoutePaths.listingEditor}?fresh=1'),
              child: Text(homiziText(context, 'Post a listing')),
            ),
          ],
        ],
      ),
    );
  }
}
