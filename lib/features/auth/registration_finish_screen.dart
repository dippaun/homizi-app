import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/auth/registration_gate.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_role_select.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';
import 'package:homizi/ui/kit/kit.dart';

enum _FinishPage { roles, details, done }

/// Role page first, then name and city, then "You're all set".
///
/// The role step is [ProfileRoleSelect], the same cards as profile edit.
/// A finished account is sent home and does not see this again.
class RegistrationFinishScreen extends ConsumerStatefulWidget {
  const RegistrationFinishScreen({super.key});

  @override
  ConsumerState<RegistrationFinishScreen> createState() =>
      _RegistrationFinishScreenState();
}

class _RegistrationFinishScreenState
    extends ConsumerState<RegistrationFinishScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _roles = <String>{};
  String? _error;
  var _busy = false;
  var _done = false;
  var _lockedIn = false;
  var _page = _FinishPage.roles;

  @override
  void initState() {
    super.initState();
    _seedRoles();
    unawaited(_prefill());
  }

  void _seedRoles() {
    final saved = ref.read(profileCreateStoreProvider).draft.roles;
    for (final role in saved) {
      if (profileWizardRoles.any((item) => item.$1 == role)) {
        _roles.add(role);
      }
    }
    if (_roles.isNotEmpty) {
      return;
    }
    final mapped = wizardRoleForWire(ref.read(sessionProvider).homiziWire);
    if (mapped != null) {
      _roles.add(mapped);
    }
  }

  Future<void> _prefill() async {
    try {
      final profile = await ref
          .read(accountGatewayProvider)
          .loadTenantProfile();
      if (!mounted) {
        return;
      }
      if (_name.text.isEmpty && profile.displayName.trim().isNotEmpty) {
        _name.text = profile.displayName.trim();
      }
      final city = profile.preferences.city.trim().isNotEmpty
          ? profile.preferences.city.trim()
          : profile.preferences.localities.isEmpty
          ? ''
          : profile.preferences.localities.first.trim();
      if (_city.text.isEmpty && city.isNotEmpty) {
        _city.text = city;
      }
    } on AccountFailure {
      // A missing row is reported when they tap Finish.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _continueRoles() async {
    final message = validateWizardRoles(_roles.toList());
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    setState(() {
      _busy = true;
      _lockedIn = true;
      _error = null;
    });
    final store = ref.read(profileCreateStoreProvider);
    await store.save(store.draft.copyWith(roles: _roles.toList()));
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _page = _FinishPage.details;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final roles = _roles.toList();
    final wire = profilePrimaryWire(ProfileCreateDraft(roles: roles));
    if (name.length < 2) {
      setState(() => _error = 'Enter the name people should see.');
      return;
    }
    if (wire == null) {
      setState(() {
        _page = _FinishPage.roles;
        _error = 'Choose how you will use HOMIZI.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _lockedIn = true;
    });
    try {
      final gateway = ref.read(accountGatewayProvider);
      final current = await gateway.loadTenantProfile();
      final city = _city.text.trim();
      final localities = [
        if (city.isNotEmpty) city,
        for (final place in current.preferences.localities)
          if (place.trim().isNotEmpty && place.trim() != city) place.trim(),
      ];
      await gateway.saveTenantProfile(
        current.copyWith(
          displayName: name,
          preferences: current.preferences.copyWith(
            city: city.isEmpty ? current.preferences.city : city,
            localities: city.isEmpty
                ? current.preferences.localities
                : localities,
          ),
        ),
      );
      final roleError = await ref
          .read(sessionProvider.notifier)
          .selectPrimaryRole(wire);
      if (roleError != null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = roleError;
          });
        }
        return;
      }
      final store = ref.read(profileCreateStoreProvider);
      await store.save(store.draft.copyWith(roles: roles, city: city));
      ref.read(registrationBypassProvider.notifier).markDone();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _done = true;
        _page = _FinishPage.done;
      });
    } on AccountFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  void _home() {
    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final needsFinish = ref.watch(registrationGateProvider).asData?.value;
    if (needsFinish == true) {
      _lockedIn = true;
    }
    if (!_done && !_lockedIn && needsFinish != true) {
      if (needsFinish == false) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _lockedIn || _done) {
            return;
          }
          context.go(RoutePaths.home);
        });
      }
      return const Scaffold(
        backgroundColor: HomiziColors.white,
        body: SizedBox.shrink(),
      );
    }
    return Scaffold(
      key: const Key('registration-finish-screen'),
      backgroundColor: HomiziColors.white,
      body: PageBackground(
        variant: PageBackgroundVariant.soft,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: switch (_page) {
                _FinishPage.roles => _rolesPage(),
                _FinishPage.details => _form(),
                _FinishPage.done => _success(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _rolesPage() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            children: [
              ProfileRoleSelect(
                selected: _roles,
                error: _error,
                errorKey: const Key('registration-error'),
                onToggle: (id) => setState(() {
                  _lockedIn = true;
                  if (!_roles.add(id)) {
                    _roles.remove(id);
                  }
                  _error = null;
                }),
              ),
            ],
          ),
        ),
        StickyCta(
          child: ShGradientButton(
            buttonKey: const Key('registration-role-continue'),
            label: 'Continue',
            busy: _busy,
            onPressed: _busy ? null : () => unawaited(_continueRoles()),
          ),
        ),
      ],
    );
  }

  Widget _form() {
    final chosen = [
      for (final role in profileWizardRoles)
        if (_roles.contains(role.$1)) homiziText(context, role.$2),
    ].join(', ');
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  key: const Key('registration-back-roles'),
                  tooltip: homiziText(context, 'Back'),
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _error = null;
                          _page = _FinishPage.roles;
                        }),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              Text(
                homiziText(context, 'Finish registration'),
                key: const Key('registration-title'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(
                  context,
                  'Add your name and a city. Then you are in.',
                ),
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  height: 1.4,
                ),
              ),
              if (chosen.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  chosen,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    color: HomiziColors.ink,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              KitTextField(
                fieldKey: const Key('registration-name'),
                label: 'Your name',
                controller: _name,
                hint: 'Meera Nair',
                icon: RealLifeIcons.person,
                textCapitalization: TextCapitalization.words,
              ),
              KitTextField(
                fieldKey: const Key('registration-city'),
                label: 'City',
                controller: _city,
                hint: 'Bengaluru',
                icon: RealLifeIcons.locality,
                textCapitalization: TextCapitalization.words,
              ),
              if (_error != null)
                Text(
                  homiziText(context, _error!),
                  key: const Key('registration-error'),
                  style: const TextStyle(color: HomiziColors.error),
                ),
            ],
          ),
        ),
        StickyCta(
          child: ShGradientButton(
            buttonKey: const Key('registration-continue'),
            label: 'Finish',
            busy: _busy,
            onPressed: _busy ? null : () => unawaited(_save()),
          ),
        ),
      ],
    );
  }

  Widget _success() {
    final wire =
        profilePrimaryWire(ProfileCreateDraft(roles: _roles.toList())) ??
        'tenant';
    final city = _city.text.trim();
    final place = city.isEmpty ? 'your city' : city;
    final detail = switch (wire) {
      'host' => 'List a home in $place whenever you are ready.',
      'broker' => 'Seeker briefs and listings for $place are on your desk.',
      'roommate' => 'Flatmate matches around $place are ready.',
      _ => 'Homes in $place are ready on your feed.',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: HomiziColors.success, size: 64),
          const SizedBox(height: 16),
          Text(
            homiziText(context, "You're all set"),
            key: const Key('registration-success'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(context, detail),
            textAlign: TextAlign.center,
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.4),
          ),
          const Spacer(),
          ShGradientButton(
            buttonKey: const Key('registration-home'),
            label: 'Home',
            icon: Icons.home_rounded,
            onPressed: _home,
          ),
        ],
      ),
    );
  }
}
