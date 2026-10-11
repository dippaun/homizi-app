import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            Text(
              'HOMIZI',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: HomiziColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find a home, or a flatmate, with contact details that stay hidden until you both agree.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 12),
            Material(
              color: HomiziColors.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: HomiziColors.line),
              ),
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
            const SizedBox(height: 8),
            Text(
              'Placeholder colors. Replace them when the brand is approved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: HomiziColors.warning,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('continue-button'),
              onPressed: _accepted
                  ? () {
                      unawaited(_continue(context, ref));
                    }
                  : null,
              child: const Text('Agree and continue'),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: HomiziColors.seed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
