import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/roles/role_flow.dart';
import 'package:homizi/features/roles/role_onboarding_widgets.dart';
import 'package:homizi/features/session/session_controller.dart';

class _RoleOption {
  const _RoleOption({
    required this.wire,
    required this.title,
    required this.detail,
    required this.icon,
    required this.cardKey,
  });

  final String wire;
  final String title;
  final String detail;
  final IconData icon;
  final Key cardKey;
}

const _options = <_RoleOption>[
  _RoleOption(
    wire: 'tenant',
    title: 'Tenant / Home-Seeker',
    detail: 'Find a home to rent in your city.',
    icon: Icons.apartment_outlined,
    cardKey: Key('role-card-tenant'),
  ),
  _RoleOption(
    wire: 'host',
    title: 'Host / Owner',
    detail: 'List a home and hear from tenants.',
    icon: Icons.vpn_key_outlined,
    cardKey: Key('role-card-host'),
  ),
  _RoleOption(
    wire: 'broker',
    title: 'Property Partner',
    detail: 'Broker or agent for seekers and owners.',
    icon: Icons.badge_outlined,
    cardKey: Key('role-card-broker'),
  ),
  _RoleOption(
    wire: 'roommate',
    title: 'Home-Sharer',
    detail: 'You have a room and want a flatmate.',
    icon: Icons.groups_outlined,
    cardKey: Key('role-card-roommate'),
  ),
];

class RoleOnboardingScreen extends ConsumerStatefulWidget {
  const RoleOnboardingScreen({super.key});

  @override
  ConsumerState<RoleOnboardingScreen> createState() =>
      _RoleOnboardingScreenState();
}

class _RoleOnboardingScreenState extends ConsumerState<RoleOnboardingScreen> {
  String? _selected;
  String? _error;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider).homiziWire;
    _selected = session;
  }

  Future<void> _continue() async {
    final wire = _selected;
    if (wire == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await persistChosenRole(ref, wire);
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }
    setState(() => _busy = false);
    openRoleSetup(context, ref, wire);
  }

  @override
  Widget build(BuildContext context) {
    return RoleFlowScaffold(
      screenKey: const Key('role-onboarding-screen'),
      title: 'How will you use HOMIZI?',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const RoleFlowIntro(
            'Pick one way in. You can change it later from Profile.',
          ),
          const SizedBox(height: 20),
          for (final option in _options) ...[
            _RoleCard(
              option: option,
              selected: _selected == option.wire,
              onTap: () => setState(() => _selected = option.wire),
            ),
            const SizedBox(height: 12),
          ],
          RoleFlowError(message: _error, errorKey: const Key('role-error')),
          const SizedBox(height: 8),
          RoleFlowContinue(
            buttonKey: const Key('role-continue'),
            label: 'Continue',
            onPressed: _selected == null || _busy
                ? null
                : () => unawaited(_continue()),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _RoleOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = homiziText(context, option.title);
    final detail = homiziText(context, option.detail);
    return Material(
      color: selected ? HomiziColors.accentWash : HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? HomiziColors.logoOrange : HomiziColors.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        key: option.cardKey,
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: HomiziColors.white,
                child: Icon(option.icon, color: HomiziColors.logoOrange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: HomiziColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        height: 1.35,
                        color: HomiziColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                color: selected ? HomiziColors.logoOrange : HomiziColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
