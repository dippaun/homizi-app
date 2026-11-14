import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/broker/broker_auth.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/tenant/tenant_intent.dart';

class PersonalizeScreen extends ConsumerStatefulWidget {
  const PersonalizeScreen({super.key});

  @override
  ConsumerState<PersonalizeScreen> createState() => _PersonalizeScreenState();
}

class _PersonalizeScreenState extends ConsumerState<PersonalizeScreen> {
  final _city = TextEditingController();
  var _busy = false;
  var _saved = false;
  var _locating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final city = ref.read(personalizationProvider).city;
    if (city.isNotEmpty) {
      _city.text = city;
    }
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    unawaited(ref.read(personalizationProvider.notifier).skip());
    if (mounted) {
      context.go(RoutePaths.home);
    }
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    var message = 'Location permission was not granted. Type your city.';
    try {
      final service = ref.read(locationServiceProvider);
      final fix = await service.currentPosition();
      if (!mounted) {
        return;
      }
      if (fix != null && !service.mapsEnabled) {
        message =
            'Location permission was granted. HOMIZI has no maps key, so it cannot name the city. Type it below. The coordinates were not saved.';
      } else if (fix != null) {
        final place = await service.reverseGeocode(fix);
        if (!mounted) {
          return;
        }
        // The city, not the neighbourhood: Ahmedabad, not Vastrapur.
        final name = (place?.city ?? '').trim();
        if (name.isNotEmpty) {
          _city.text = name;
          ref.read(personalizationProvider.notifier).setCity(name);
          message = 'Location set from maps. You can edit the city.';
        } else {
          message =
              'Location was shared, but maps did not name the city. Type it below. The coordinates were not saved.';
        }
      }
    } on Object {
      message = 'Location could not be read. Type your city.';
    } finally {
      if (mounted) {
        ref.read(personalizationProvider.notifier).setLocationNote(message);
        setState(() => _locating = false);
      }
    }
  }

  Future<void> _save() async {
    final notifier = ref.read(personalizationProvider.notifier);
    notifier.setCity(_city.text.trim());
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await notifier.save();
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _error = error;
      _saved = error == null;
    });
  }

  void _role(String wire) {
    final phase = ref.read(sessionProvider).phase;
    ref.read(personalizationProvider.notifier).setRole(wire);
    if (phase == SessionPhase.signedOut && wire == 'broker') {
      context.go(brokerProfileSignInLocation());
      return;
    }
    if (phase == SessionPhase.needsRole || phase == SessionPhase.ready) {
      unawaited(_applySignedIn(wire));
    }
  }

  Future<void> _applySignedIn(String wire) async {
    final error = await ref
        .read(sessionProvider.notifier)
        .selectPrimaryRole(wire);
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final pendingProfile =
        ref.read(tenantIntentProvider) == TenantIntent.profile;
    final hostNext = ref.read(hostIntentProvider).afterAuth;
    final next = switch (wire) {
      'roommate' => '${RoutePaths.requirement}?kind=roommate',
      'tenant' =>
        pendingProfile
            ? RoutePaths.tenantSetup
            : '${RoutePaths.requirement}?kind=tenant',
      'host' => hostNext ?? RoutePaths.hostHome,
      'broker' => RoutePaths.brokerRegister,
      _ => RoutePaths.home,
    };
    context.go(next);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(personalizationProvider);
    final signedIn = ref.watch(sessionProvider).phase == SessionPhase.ready;
    return Scaffold(
      key: const Key('personalize-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Personalize')),
        actions: [
          TextButton(
            key: const Key('personalize-skip'),
            onPressed: _busy ? null : () => unawaited(_skip()),
            child: Text(homiziText(context, 'Skip')),
          ),
        ],
      ),
      body: _saved
          ? _Saved(
              onDevice: ref
                  .read(personalizationProvider.notifier)
                  .deviceWriteOk,
              signedIn: signedIn,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  homiziText(
                    context,
                    'Tell HOMIZI what you are looking for. You can skip this and browse first.',
                  ),
                  style: const TextStyle(color: HomiziColors.inkSoft),
                ),
                const SizedBox(height: 20),
                const _Label('How will you use HOMIZI?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Choice(
                      choiceKey: const Key('role-card-tenant'),
                      label: 'Tenant / Home-Seeker',
                      selected: prefs.roleWire == 'tenant',
                      onTap: () => _role('tenant'),
                    ),
                    _Choice(
                      choiceKey: const Key('role-card-host'),
                      label: 'Host / Owner',
                      selected: prefs.roleWire == 'host',
                      onTap: () => _role('host'),
                    ),
                    _Choice(
                      choiceKey: const Key('role-card-broker'),
                      label: 'Property Partner',
                      selected: prefs.roleWire == 'broker',
                      onTap: () => _role('broker'),
                    ),
                    _Choice(
                      choiceKey: const Key('role-card-roommate'),
                      label: 'Home-Sharer',
                      selected: prefs.roleWire == 'roommate',
                      onTap: () => _role('roommate'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _Label('Preferred city'),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('personalize-city'),
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: homiziText(context, 'City'),
                    filled: true,
                    fillColor: HomiziColors.soft,
                  ),
                  onChanged: (value) => ref
                      .read(personalizationProvider.notifier)
                      .setCity(value.trim()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final city in personalCities)
                      _Choice(
                        label: city,
                        selected: _city.text == city,
                        onTap: () {
                          _city.text = city;
                          ref
                              .read(personalizationProvider.notifier)
                              .setCity(city);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const Key('personalize-locate'),
                  onPressed: _locating ? null : () => unawaited(_locate()),
                  icon: _locating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_outlined),
                  label: Text(homiziText(context, 'Use my location')),
                ),
                if (prefs.locationNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    key: const Key('personalize-location-note'),
                    homiziText(context, prefs.locationNote),
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                ],
                const SizedBox(height: 20),
                const _Label('What are you looking for?'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in personalLookingFor.entries)
                      _Choice(
                        label: entry.value,
                        selected: prefs.lookingFor == entry.key,
                        onTap: () => ref
                            .read(personalizationProvider.notifier)
                            .setLookingFor(entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const _Label('Indicative budget'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final band in personalBudgets)
                      _Choice(
                        label: band.label,
                        selected:
                            prefs.budgetMin == band.min &&
                            prefs.budgetMax == band.max,
                        onTap: () => ref
                            .read(personalizationProvider.notifier)
                            .setBudget(band.min, band.max),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const _Label('Optional preferences'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final entry in personalPreferenceChoices.entries)
                      _Choice(
                        label: entry.value,
                        selected: prefs.preferences.contains(entry.key),
                        onTap: () => ref
                            .read(personalizationProvider.notifier)
                            .togglePreference(entry.key),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                const _Label('Language'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _Choice(
                      label: 'English',
                      selected: prefs.language == 'en',
                      onTap: () => ref
                          .read(personalizationProvider.notifier)
                          .setLanguage('en'),
                    ),
                    _Choice(
                      label: 'Hindi',
                      selected: prefs.language == 'hi',
                      onTap: () => ref
                          .read(personalizationProvider.notifier)
                          .setLanguage('hi'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const _Label('Appearance'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _Choice(
                      choiceKey: const Key('personalize-theme-light'),
                      label: 'Light',
                      selected: prefs.theme != 'dark',
                      onTap: () => ref
                          .read(personalizationProvider.notifier)
                          .setTheme('light'),
                    ),
                    _Choice(
                      choiceKey: const Key('personalize-theme-dark'),
                      label: 'Dark',
                      selected: prefs.theme == 'dark',
                      onTap: () => ref
                          .read(personalizationProvider.notifier)
                          .setTheme('dark'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    key: const Key('personalize-error'),
                    homiziText(context, _error!),
                    style: const TextStyle(color: HomiziColors.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  key: const Key('personalize-save'),
                  onPressed: _busy ? null : () => unawaited(_save()),
                  child: Text(
                    homiziText(context, _busy ? 'Saving…' : 'Save preferences'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved({required this.onDevice, required this.signedIn});

  final bool onDevice;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    final detail = signedIn
        ? 'Your role and budget are on your account when that write succeeded.'
        : 'Saved on this device. HOMIZI copies this into your account after you sign up.';
    final storage = onDevice
        ? detail
        : '$detail Storage on this device did not accept a lasting write, so this visit keeps the copy.';
    return ListView(
      key: const Key('personalize-saved'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        const Icon(Icons.check_circle, color: HomiziColors.success, size: 48),
        const SizedBox(height: 16),
        Text(
          homiziText(context, 'Preferences saved'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(homiziText(context, storage)),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('personalize-done'),
          onPressed: () => context.go(RoutePaths.home),
          child: Text(homiziText(context, 'Back to Home')),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      homiziText(context, text),
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: HomiziColors.ink,
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.choiceKey,
  });

  final Key? choiceKey;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      key: choiceKey,
      label: Text(homiziText(context, label)),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: HomiziColors.accentWash,
      checkmarkColor: HomiziColors.ink,
      labelStyle: const TextStyle(color: HomiziColors.ink),
    );
  }
}
