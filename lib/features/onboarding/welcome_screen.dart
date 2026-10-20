import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_auth.dart';
import 'package:homizi/features/host/host_intent.dart';
import 'package:homizi/features/roommates/flatmate_return.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/features/tenant/tenant_intent.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _page = PageController();
  var _accepted = false;
  var _pageIndex = 0;

  static const _slides = <_SlideData>[
    _SlideData(
      icon: Icons.home_outlined,
      title: 'Find a home without the noise.',
      body:
          'Find a home, or a flatmate, with contact details that stay hidden until you both agree.',
    ),
    _SlideData(
      icon: Icons.verified_outlined,
      title: 'Profiles with a verification status',
      body:
          'Identity checks are mocked in this build. No Aadhaar number or face scan is collected.',
    ),
    _SlideData(
      icon: Icons.lock_outline,
      title: 'A server-side contact gate',
      body:
          'A phone or email is returned only after a mutual match and explicit consent.',
    ),
  ];

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return MinTouchScope(
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slideHeight = (constraints.maxHeight * 0.28).clamp(
                96.0,
                280.0,
              );
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: BrandLockup(markSize: 40),
                    ),
                  ),
                  SizedBox(
                    height: slideHeight,
                    child: PageView.builder(
                      key: const Key('onboarding-carousel'),
                      controller: _page,
                      itemCount: _slides.length,
                      onPageChanged: (index) =>
                          setState(() => _pageIndex = index),
                      itemBuilder: (context, index) {
                        final slide = _slides[index];
                        return _Slide(
                          key: Key('onboarding-slide-$index'),
                          data: slide,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(
                            homiziText(
                              context,
                              'Slide ${_pageIndex + 1} of ${_slides.length}',
                            ),
                            key: const Key('onboarding-page'),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (
                                var index = 0;
                                index < _slides.length;
                                index++
                              )
                                Semantics(
                                  button: true,
                                  selected: index == _pageIndex,
                                  label: homiziText(
                                    context,
                                    'Slide ${index + 1} of ${_slides.length}',
                                  ),
                                  child: InkWell(
                                    onTap: () {
                                      if (reduceMotion) {
                                        _page.jumpToPage(index);
                                        return;
                                      }
                                      unawaited(
                                        _page.animateToPage(
                                          index,
                                          duration: const Duration(
                                            milliseconds: 280,
                                          ),
                                          curve: Curves.easeOutCubic,
                                        ),
                                      );
                                    },
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Center(
                                        child: AnimatedContainer(
                                          duration: motionDuration(
                                            context,
                                            const Duration(milliseconds: 180),
                                          ),
                                          curve: Curves.easeOutCubic,
                                          width: index == _pageIndex ? 22 : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: index == _pageIndex
                                                ? HomiziColors.accent
                                                : scheme.outline,
                                            borderRadius:
                                                const BorderRadius.all(
                                                  Radius.circular(8),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: Column(
                              children: [
                                Card.outlined(
                                  margin: EdgeInsets.zero,
                                  child: CheckboxListTile(
                                    key: const Key('consent-checkbox'),
                                    value: _accepted,
                                    onChanged: (value) => setState(
                                      () => _accepted = value ?? false,
                                    ),
                                    title: Text(
                                      homiziText(
                                        context,
                                        'I agree to the HOMIZI terms and privacy notice (draft ${config.policyVersion}).',
                                      ),
                                    ),
                                    subtitle: Text(
                                      homiziText(
                                        context,
                                        'Legal text is not approved yet. Demo mode keeps the acceptance in this session. With Supabase configured, the draft version is stored on your account after you sign in.',
                                      ),
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    key: const Key('continue-button'),
                                    onPressed: _accepted
                                        ? () {
                                            unawaited(_continue(context, ref));
                                          }
                                        : null,
                                    child: Text(
                                      homiziText(context, 'Agree and continue'),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    key: const Key('welcome-role-tenant'),
                                    onPressed: () =>
                                        unawaited(_startTenantProfile()),
                                    icon: const Icon(Icons.apartment_outlined),
                                    label: Text(
                                      homiziText(
                                        context,
                                        'Tenant · Find a home to rent',
                                      ),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  key: const Key('create-profile-before-login'),
                                  onPressed: () =>
                                      unawaited(_startTenantProfile()),
                                  child: Text(
                                    homiziText(
                                      context,
                                      'Sign in to create your tenant profile.',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    key: const Key('create-profile'),
                                    onPressed: _accepted
                                        ? () {
                                            ref
                                                .read(
                                                  hostIntentProvider.notifier,
                                                )
                                                .remember(
                                                  RoutePaths.hostProfile,
                                                  afterProfile: RoutePaths.home,
                                                );
                                            ref
                                                .read(
                                                  flatmateReturnProvider
                                                      .notifier,
                                                )
                                                .setPath(flatmateProfileNext);
                                            unawaited(_continue(context, ref));
                                          }
                                        : null,
                                    child: Text(
                                      homiziText(context, 'Create profile'),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    key: const Key('welcome-create-profile'),
                                    onPressed: () {
                                      if (!_accepted) {
                                        setState(() => _accepted = true);
                                      }
                                      unawaited(
                                        _createBrokerProfile(context, ref),
                                      );
                                    },
                                    child: Text(
                                      homiziText(
                                        context,
                                        'Create broker profile',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _startTenantProfile() async {
    if (!_accepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            homiziText(
              context,
              'Agree to the terms and privacy notice, then create your profile.',
            ),
          ),
        ),
      );
      return;
    }
    ref.read(tenantIntentProvider.notifier).requestProfile();
    final error = await ref.read(sessionProvider.notifier).acceptConsent();
    if (!mounted) {
      return;
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(homiziText(context, error))));
      return;
    }
    context.go(RoutePaths.login);
  }
}

Future<void> _continue(
  BuildContext context,
  WidgetRef ref, {
  bool openProfile = false,
}) async {
  final error = await ref.read(sessionProvider.notifier).acceptConsent();
  if (!context.mounted) {
    return;
  }
  if (error != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(homiziText(context, error))));
    return;
  }
  if (openProfile) {
    ref.read(flatmateReturnProvider.notifier).setPath(flatmateProfileNext);
  }
  if (ref.read(sessionProvider).phase == SessionPhase.signedOut) {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    context.go(RoutePaths.login);
  }
}

Future<void> _createBrokerProfile(BuildContext context, WidgetRef ref) async {
  final error = await ref.read(sessionProvider.notifier).acceptConsent();
  if (!context.mounted) {
    return;
  }
  if (error != null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(homiziText(context, error))));
    return;
  }
  context.go(brokerProfileSignInLocation());
}

class _SlideData {
  const _SlideData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _Slide extends StatelessWidget {
  const _Slide({required this.data, super.key});

  final _SlideData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.surface,
                      border: Border.all(color: HomiziColors.accent, width: 2),
                    ),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: Icon(
                        data.icon,
                        size: 32,
                        color: HomiziColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    homiziText(context, data.title),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    homiziText(context, data.body),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
