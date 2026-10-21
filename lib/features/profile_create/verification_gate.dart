import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/profile_create_screen.dart';

/// Runs [action] when this person is verified.
///
/// Browsing stays open. Contact, chat, interest, and posting ask for the
/// create-profile flow, then come back to the same action.
Future<void> guardVerifiedAction(
  BuildContext context,
  WidgetRef ref, {
  required VerifiedAction action,
}) async {
  if (ref.read(ownVerificationProvider).isVerified) {
    await action();
    return;
  }
  if (!context.mounted) {
    return;
  }
  final proceed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: HomiziColors.white,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          key: const Key('verify-to-continue-sheet'),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                homiziText(sheetContext, 'Verify to continue'),
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  color: HomiziColors.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(
                  sheetContext,
                  'Anyone can browse homes. Contacting someone, chatting, showing interest, or posting a property or a brief needs a verified profile.',
                ),
                style: Theme.of(
                  sheetContext,
                ).textTheme.bodyLarge?.copyWith(color: HomiziColors.ink),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    key: const Key('verify-later'),
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: Text(homiziText(sheetContext, 'Not now')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('verify-now'),
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: Text(homiziText(sheetContext, 'Verify now')),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  if (proceed != true || !context.mounted) {
    return;
  }
  ref.read(pendingVerifiedActionProvider.notifier).arm(action);
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push(RoutePaths.profileCreate);
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(builder: (context) => const ProfileCreateScreen()),
  );
}
