import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/broker/broker_briefs_screen.dart';
import 'package:homizi/features/broker/broker_home_screen.dart';
import 'package:homizi/features/broker/broker_listings_screen.dart';
import 'package:homizi/features/host/host_home_gate.dart';
import 'package:homizi/features/owner/owner_dashboard_screen.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/seekers/seekers_screen.dart';

class BrokerHomeGate extends ConsumerWidget {
  const BrokerHomeGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentRoleProvider) == HomiziRole.broker) {
      return const BrokerHomeScreen();
    }
    return const HostHomeGate();
  }
}

class BrokerSeekersGate extends ConsumerWidget {
  const BrokerSeekersGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentRoleProvider) == HomiziRole.broker) {
      return const BrokerBriefsScreen();
    }
    return const SeekersScreen();
  }
}

class BrokerListingsGate extends ConsumerWidget {
  const BrokerListingsGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(currentRoleProvider) == HomiziRole.broker) {
      return const BrokerListingsScreen();
    }
    return const OwnerDashboardScreen();
  }
}
