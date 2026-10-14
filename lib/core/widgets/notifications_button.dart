import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';

class NotificationsButton extends StatelessWidget {
  const NotificationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('open-notifications'),
      tooltip: homiziText(context, 'Notifications'),
      onPressed: () => context.push(RoutePaths.notifications),
      icon: const Icon(Icons.notifications_outlined),
    );
  }
}
