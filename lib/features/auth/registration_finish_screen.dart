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
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';
import 'package:homizi/ui/kit/kit.dart';

class _RoleChoice {
  const _RoleChoice({
    required this.wire,
    required this.label,
    required this.icon,
    required this.tileKey,
  });

  final String wire;
  final String label;
  final IconData icon;
  final Key tileKey;
}

const _roles = <_RoleChoice>[
  _RoleChoice(
    wire: 'tenant',
    label: 'Tenant',
    icon: RealLifeIcons.house,
    tileKey: Key('registration-role-tenant'),
  ),
  _RoleChoice(
    wire: 'host',
    label: 'Owner / Host',
    icon: RealLifeIcons.badge,
    tileKey: Key('registration-role-host'),
  ),
  _RoleChoice(
    wire: 'broker',
    label: 'Property partner',
    icon: RealLifeIcons.briefcase,
    tileKey: Key('registration-role-broker'),
  ),
  _RoleChoice(
    wire: 'roommate',
    label: 'Home-sharer',
    icon: RealLifeIcons.sharedRoom,
    tileKey: Key('registration-role-roommate'),
  ),
];

/// Name, role, and a city, then "You're all set".
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
  String? _role;
  String? _error;
  var _busy = false;
  var _done = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    _role = isHomiziRoleWire(session.homiziWire) ? session.homiziWire : null;
    unawaited(_prefill());
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

  Future<void> _save() async {
    final name = _name.text.trim();
    final role = _role;
    if (name.length < 2) {
      setState(() => _error = 'Enter the name people should see.');
      return;
    }
    if (!isHomiziRoleWire(role)) {
      setState(() => _error = 'Choose how you will use HOMIZI.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
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
          .selectPrimaryRole(role!);
      if (roleError != null) {
        if (mounted) {
          setState(() {
            _busy = false;
            _error = roleError;
          });
        }
        return;
      }
      ref.read(registrationBypassProvider.notifier).markDone();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _done = true;
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
              child: _done ? _success() : _form(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
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
                  'Add your name, confirm your role, and a city. Then you are in.',
                ),
                style: const TextStyle(
                  color: HomiziColors.inkSoft,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              KitTextField(
                fieldKey: const Key('registration-name'),
                label: 'Your name',
                controller: _name,
                hint: 'Meera Nair',
                icon: RealLifeIcons.person,
                textCapitalization: TextCapitalization.words,
              ),
              Text(
                homiziText(context, 'How will you use HOMIZI?'),
                style: kitFieldLabelStyle,
              ),
              const SizedBox(height: 8),
              OptionGrid(
                minTileWidth: 140,
                maxColumns: 2,
                children: [
                  for (final role in _roles)
                    OptionTile(
                      key: role.tileKey,
                      label: homiziText(context, role.label),
                      icon: role.icon,
                      selected: _role == role.wire,
                      onTap: () => setState(() => _role = role.wire),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
    final wire = _role ?? 'tenant';
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
