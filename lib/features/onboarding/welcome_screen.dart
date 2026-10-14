import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: HomiziColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                children: [
                  const BrandLockup(markSize: 44),
                  const SizedBox(height: 28),
                  Text(
                    'Find a home without the noise.',
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Find a home, or a flatmate, with contact details that stay hidden until you both agree.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  const _Point(
                    icon: Icons.verified_outlined,
                    title: 'Profiles with a verification status',
                    body: 'Identity checks are mocked in this build. No Aadhaar number or face scan is collected.',
                  ),
                  const _Point(
                    icon: Icons.home_outlined,
                    title: 'Listings and requirements',
                    body: 'Tenants describe what they need. Hosts publish a home with rent, deposit, and photos.',
                  ),
                  const _Point(
                    icon: Icons.lock_outline,
                    title: 'A server-side contact gate',
                    body: 'A phone or email is returned only after a mutual match and explicit consent.',
                  ),
                ],
              ),
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
                      onChanged: (value) =>
                          setState(() => _accepted = value ?? false),
                      title: Text(
                        'I agree to the HOMIZI terms and privacy notice (draft ${config.policyVersion}).',
                      ),
                      subtitle: const Text(
                        'Legal text is not approved yet. Demo mode keeps the acceptance in this session. With Supabase configured, the draft version is stored on your account after you sign in.',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
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
                      child: const Text('Agree and continue'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _continue(BuildContext context, WidgetRef ref) async {
  final error = await ref.read(sessionProvider.notifier).acceptConsent();
  if (!context.mounted) {
    return;
  }
  if (error != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  if (ref.read(sessionProvider).phase == SessionPhase.signedOut) {
    context.go(RoutePaths.login);
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.only(bottom: 8),
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
    );
  }
}
