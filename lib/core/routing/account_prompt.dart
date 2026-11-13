import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/session/session_state.dart';

/// Sign-in URL that returns to [next] after the session is ready.
String signInReturn(String next) {
  return Uri(
    path: RoutePaths.login,
    queryParameters: {'next': next},
  ).toString();
}

bool sessionIsReady(SessionState session) =>
    session.phase == SessionPhase.ready;

/// Opens [path] when the session is ready. Otherwise asks, then opens sign-in
/// and comes back to [path].
Future<void> openAccountPath(
  BuildContext context,
  SessionState session,
  String path,
) async {
  if (sessionIsReady(session)) {
    unawaited(context.push(path));
    return;
  }
  final proceed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: const Key('sign-in-prompt'),
        title: Text(homiziText(dialogContext, 'Sign in to continue')),
        content: Text(
          homiziText(
            dialogContext,
            'This stays on your account. After sign-in you come back to this step.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(homiziText(dialogContext, 'Not now')),
          ),
          FilledButton(
            key: const Key('sign-in-prompt-continue'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(homiziText(dialogContext, 'Sign in')),
          ),
        ],
      );
    },
  );
  if (proceed == true && context.mounted) {
    unawaited(context.push(signInReturn(path)));
  }
}
