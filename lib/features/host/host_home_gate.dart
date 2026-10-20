import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/home/home_screen.dart';
import 'package:homizi/features/host/host_home_screen.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/roommates/roommate_screen.dart';
import 'package:homizi/features/session/session_controller.dart';

/// Hosts land on the owner hub. Other roles keep the shared home.
class HostHomeGate extends ConsumerWidget {
  const HostHomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(currentRoleProvider);
    final wire = ref.watch(sessionProvider).homiziWire;
    if (role == HomiziRole.host || wire == 'host') {
      return const HostHomeScreen();
    }
    if (role == HomiziRole.roommate || wire == 'roommate') {
      return const RoommateScreen();
    }
    return const HomeScreen();
  }
}
