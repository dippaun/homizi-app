import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/broker/broker_auth.dart';
import 'package:homizi/features/broker/broker_chip.dart';
import 'package:homizi/features/broker/broker_links.dart';
import 'package:homizi/features/broker/broker_profile.dart';
import 'package:homizi/features/broker/broker_providers.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class BrokerHomeScreen extends ConsumerStatefulWidget {
  const BrokerHomeScreen({super.key});

  @override
  ConsumerState<BrokerHomeScreen> createState() => _BrokerHomeScreenState();
}

class _BrokerHomeScreenState extends ConsumerState<BrokerHomeScreen> {
  BrokerProfileDraft? _profile;
  var _loaded = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final loaded = await ref.read(brokerGatewayProvider).load();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = loaded;
        _loaded = true;
      });
    } on BrokerFailure {
      if (!mounted) {
        return;
      }
      setState(() => _loaded = true);
    }
  }

  void _createProfile() {
    final phase = ref.read(sessionProvider).phase;
    final router = GoRouter.of(context);
    if (phase == SessionPhase.ready || phase == SessionPhase.needsRole) {
      router.push(RoutePaths.brokerRegister);
      return;
    }
    router.go(brokerProfileSignInLocation());
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final name = profile?.fullName.trim() ?? '';
    final saved = _loaded && name.isNotEmpty;
    return Scaffold(
      key: const Key('broker-home-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        title: Text(homiziText(context, 'Broker')),
        actions: [
          IconButton(
            key: const Key('broker-open-notifications'),
            tooltip: homiziText(context, 'Notifications'),
            onPressed: () => context.push(RoutePaths.notifications),
            icon: const Icon(Icons.notifications_outlined),
          ),
          IconButton(
            key: const Key('broker-open-settings'),
            tooltip: homiziText(context, 'Settings'),
            onPressed: () => context.push(RoutePaths.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
          PopupMenuButton<BrokerLink>(
            key: const Key('broker-menu'),
            tooltip: homiziText(context, 'Menu'),
            onSelected: (link) => openBrokerLink(context, link),
            itemBuilder: (context) => [
              for (final link in brokerLinks)
                PopupMenuItem<BrokerLink>(
                  key: Key('broker-menu-${link.tileKey}'),
                  value: link,
                  child: Text(homiziText(context, link.label)),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const BrokerChip(),
          const SizedBox(height: 12),
          Text(
            homiziText(context, saved ? 'Hello, $name' : 'Your broker desk'),
            key: const Key('broker-home-title'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            homiziText(
              context,
              saved
                  ? '${profile?.agencyName.trim() ?? ''} · ${profile?.cities.join(', ') ?? ''}'
                  : 'Briefs, listings, leads, chats, and visits for the homes you manage.',
            ),
          ),
          if (_loaded && !saved) ...[
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('broker-home-create-profile'),
              onPressed: _createProfile,
              child: Text(homiziText(context, 'Create profile')),
            ),
          ],
          const SizedBox(height: 20),
          for (final link in brokerLinks) ...[
            _DeskTile(link: link, onTap: () => openBrokerLink(context, link)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _DeskTile extends StatelessWidget {
  const _DeskTile({required this.link, required this.onTap});

  final BrokerLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key(link.tileKey),
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(link.icon, color: HomiziColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  homiziText(context, link.label),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right, color: HomiziColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
