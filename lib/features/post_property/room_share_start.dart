import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/routing/sign_in_gate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/registration_gate.dart';
import 'package:homizi/features/post_property/post_property_chooser_screen.dart';
import 'package:homizi/features/post_property/post_property_chrome.dart';
import 'package:homizi/features/post_property/post_resume.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Tenant "Post your property" starts here. Shared room or full house,
/// then registration if it is not finished, then the listing flow.
class RoomShareStart extends ConsumerStatefulWidget {
  const RoomShareStart({super.key});

  @override
  ConsumerState<RoomShareStart> createState() => _RoomShareStartState();
}

class _RoomShareStartState extends ConsumerState<RoomShareStart> {
  String _kind = 'shared';

  Future<void> _continue() async {
    final next = '${RoutePaths.postRoomList}?kind=$_kind';
    if (!ref.read(signedInProvider)) {
      ref.read(postResumeProvider.notifier).remember(next);
      ref.read(signInReturnPathProvider.notifier).remember(next);
      if (!mounted) {
        return;
      }
      await context.push(signInGateLogin(returnTo: next, signup: true));
      return;
    }
    final needs = await ref.read(registrationGateProvider.future);
    if (!mounted) {
      return;
    }
    if (needs) {
      ref.read(postResumeProvider.notifier).remember(next);
      context.go(RoutePaths.registerFinish);
      return;
    }
    unawaited(context.push(next));
  }

  @override
  Widget build(BuildContext context) {
    return PostPropertyPage(
      pageKey: const Key('room-share-start'),
      footer: PostGradientButton(
        buttonKey: const Key('room-share-continue'),
        label: 'Continue',
        onPressed: () => unawaited(_continue()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(
            homiziText(context, 'What are you sharing?'),
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              'A room in the home you already live in, or the whole house.',
            ),
            style: const TextStyle(color: HomiziColors.inkSoft, height: 1.35),
          ),
          const SizedBox(height: 16),
          OptionGrid(
            children: [
              OptionTile(
                key: const Key('room-share-shared'),
                label: 'Shared room',
                icon: Icons.groups_outlined,
                selected: _kind == 'shared',
                onTap: () => setState(() => _kind = 'shared'),
              ),
              OptionTile(
                key: const Key('room-share-full'),
                label: 'Full house',
                icon: Icons.home_outlined,
                selected: _kind == 'full',
                onTap: () => setState(() => _kind = 'full'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Opens the chooser for a host, and the room-sharer start for a tenant.
class PostPropertyEntry extends ConsumerWidget {
  const PostPropertyEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    if (role == HomiziRole.tenant || role == HomiziRole.roommate) {
      return const RoomShareStart();
    }
    return const PostPropertyChooserScreen();
  }
}
