import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';

/// Every broker home tile. The widget test walks this same list.
class BrokerLink {
  const BrokerLink({
    required this.tileKey,
    required this.label,
    required this.icon,
    required this.location,
    required this.screenKey,
  });

  final String tileKey;
  final String label;
  final IconData icon;
  final String location;
  final String screenKey;
}

const brokerLinks = <BrokerLink>[
  BrokerLink(
    tileKey: 'broker-tile-briefs',
    label: 'Requirement briefs',
    icon: Icons.assignment_outlined,
    location: RoutePaths.seekers,
    screenKey: 'broker-briefs-screen',
  ),
  BrokerLink(
    tileKey: 'broker-tile-listings',
    label: 'Listings',
    icon: Icons.home_work_outlined,
    location: RoutePaths.listings,
    screenKey: 'broker-listings-screen',
  ),
  BrokerLink(
    tileKey: 'broker-tile-leads',
    label: 'Leads',
    icon: Icons.inbox_outlined,
    location: RoutePaths.brokerLeads,
    screenKey: 'broker-leads-screen',
  ),
  BrokerLink(
    tileKey: 'broker-tile-chats',
    label: 'Chats',
    icon: Icons.chat_bubble_outline,
    location: RoutePaths.brokerChats,
    screenKey: 'broker-chats-screen',
  ),
  BrokerLink(
    tileKey: 'broker-tile-visits',
    label: 'Visits',
    icon: Icons.event_outlined,
    location: RoutePaths.brokerVisits,
    screenKey: 'broker-visits-screen',
  ),
  BrokerLink(
    tileKey: 'broker-tile-profile',
    label: 'Broker profile',
    icon: Icons.badge_outlined,
    location: RoutePaths.brokerRegister,
    screenKey: 'broker-registration-screen',
  ),
];

const _shellLocations = <String>{
  RoutePaths.home,
  RoutePaths.seekers,
  RoutePaths.listings,
  RoutePaths.matches,
  RoutePaths.profile,
};

void openBrokerLink(BuildContext context, BrokerLink link) {
  final router = GoRouter.of(context);
  if (_shellLocations.contains(link.location)) {
    router.go(link.location);
    return;
  }
  router.push(link.location);
}
