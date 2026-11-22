import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/registration_gate.dart';
import 'package:homizi/features/post_property/post_resume.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_role_select.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shared_home/shared_home_widgets.dart';
import 'package:homizi/ui/kit/kit.dart';

enum _FinishPage { roles, done }

/// Role page first, then the original profile wizard, then "You're all set".
///
/// The role step is [ProfileRoleSelect]. The wizard is Create Your Profile.
/// A finished account is sent home and does not see this again.
class RegistrationFinishScreen extends ConsumerStatefulWidget {
  const RegistrationFinishScreen({this.ready = false, super.key});

  /// Opened after the profile wizard so the closing page can show.
  final bool ready;

  @override
  ConsumerState<RegistrationFinishScreen> createState() =>
      _RegistrationFinishScreenState();
}

class _RegistrationFinishScreenState
    extends ConsumerState<RegistrationFinishScreen> {
  final _roles = <String>{};
  String? _error;
  var _busy = false;
  var _done = false;
  var _lockedIn = false;
  var _page = _FinishPage.roles;
  var _place = '';

  @override
  void initState() {
    super.initState();
    _seedRoles();
    if (widget.ready) {
      _done = true;
      _lockedIn = true;
      _page = _FinishPage.done;
      final draft = ref.read(profileCreateStoreProvider).draft;
      _place = draft.city.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        ref.read(registrationBypassProvider.notifier).markDone();
      });
    }
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

  Future<void> _continueRoles() async {
    final stored = rolesForGoals(_roles);
    final message = validateWizardRoles(stored);
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
    final nextStep = store.draft.step < profileStepBasic
        ? profileStepBasic
        : store.draft.step;
    final tags = [
      for (final tag in store.draft.tags)
        if (tag != roommateGoalTag &&
            tag != tenantGoalTag &&
            tag != sharerGoalTag &&
            tag != hostGoalTag)
          tag,
      ...goalTagsFor(_roles),
    ];
    await store.save(
      store.draft.copyWith(roles: stored, tags: tags, step: nextStep),
    );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    await context.push('${RoutePaths.profileCreate}?registration=1');
  }

  void _home() {
    ref.read(registrationBypassProvider.notifier).markDone();
    ref.read(registrationHomePassProvider.notifier).allow();
    final next = ref.read(postResumeProvider.notifier).take();
    context.go(next ?? RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    final gate = ref.watch(registrationGateProvider);
    final needsFinish = gate.isLoading ? null : gate.asData?.value;
    final session = ref.watch(sessionProvider);
    final named = profilePublicName(
      ref.watch(profileCreateStoreProvider).draft,
    );
    final alreadyHome = registrationIsComplete(
      displayName: named,
      roleWire: session.homiziWire,
    );
    if (alreadyHome && !_done) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _home();
      });
      return const Scaffold(
        key: Key('registration-skip-complete'),
        backgroundColor: HomiziColors.white,
        body: SizedBox.shrink(),
      );
    }
    if (needsFinish == true && !widget.ready) {
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
                goals: firstLoginGoals,
                heading: 'What do you want to do?',
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

  Widget _success() {
    final wire =
        profilePrimaryWire(ProfileCreateDraft(roles: _roles.toList())) ??
        'tenant';
    final place = _place.isEmpty ? 'your city' : _place;
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
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: const Icon(
              Icons.check_circle,
              color: HomiziColors.success,
              size: 64,
            ),
          ),
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
