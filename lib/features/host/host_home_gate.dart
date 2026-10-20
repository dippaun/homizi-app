import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/home/home_screen.dart';
import 'package:homizi/features/host/host_home_screen.dart';
import 'package:homizi/features/roles/role_provider.dart';

/// Hosts land on the owner hub. Other roles keep the shared home.
class HostHomeGate extends ConsumerWidget {
  const HostHomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentRoleProvider) == HomiziRole.host) {
      return const HostHomeScreen();
    }
    return const HomeScreen();
  }
}
