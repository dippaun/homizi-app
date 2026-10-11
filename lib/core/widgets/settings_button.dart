import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';

class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Settings',
      onPressed: () => context.push(RoutePaths.settings),
      icon: const Icon(Icons.settings_outlined),
    );
  }
}
