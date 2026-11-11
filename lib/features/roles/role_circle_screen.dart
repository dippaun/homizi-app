import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

/// Create-profile role picker. Four circles in a 2×2, split by a thin cross.
class RoleCircleScreen extends ConsumerWidget {
  const RoleCircleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      key: const Key('role-circle-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Create your profile')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            children: [
              Text(
                homiziText(context, 'How will you use HOMIZI?'),
                style: const TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(
                  context,
                  'Pick one way in. You can change it later.',
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 1.35,
                  color: HomiziColors.inkSoft,
                ),
              ),
              const SizedBox(height: 28),
              const _CircleGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleChoice {
  const _CircleChoice({
    required this.circleKey,
    required this.wire,
    required this.label,
    required this.path,
    required this.image,
    required this.icon,
  });

  final Key circleKey;
  final String wire;
  final String label;
  final String path;
  final String image;
  final IconData icon;
}

const _choices = <_CircleChoice>[
  _CircleChoice(
    circleKey: Key('role-circle-tenant'),
    wire: 'tenant',
    label: 'Tenant',
    path: RoutePaths.flowTenant,
    image: 'assets/images/home/apartment.webp',
    icon: Icons.apartment,
  ),
  _CircleChoice(
    circleKey: Key('role-circle-host'),
    wire: 'host',
    label: 'Owner/Host',
    path: RoutePaths.flowHost,
    image: 'assets/images/home/house.webp',
    icon: Icons.house_outlined,
  ),
  _CircleChoice(
    circleKey: Key('role-circle-roommate'),
    wire: 'roommate',
    label: 'Roommate Finder',
    path: RoutePaths.roomie,
    image: 'assets/images/home/roomies.jpg',
    icon: Icons.groups_outlined,
  ),
  _CircleChoice(
    circleKey: Key('role-circle-broker'),
    wire: 'broker',
    label: 'Broker',
    path: RoutePaths.flowBroker,
    image: 'assets/photos/exterior_01.webp',
    icon: Icons.real_estate_agent_outlined,
  ),
];

class _CircleGrid extends ConsumerWidget {
  const _CircleGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _CircleRow(left: _choices[0], right: _choices[1], ref: ref),
        const _CrossGap(),
        _CircleRow(left: _choices[2], right: _choices[3], ref: ref),
      ],
    );
  }
}

class _CircleRow extends StatelessWidget {
  const _CircleRow({
    required this.left,
    required this.right,
    required this.ref,
  });

  final _CircleChoice left;
  final _CircleChoice right;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Circle(choice: left, onTap: () => _open(context)),
          ),
          const _CrossGap(vertical: true),
          Expanded(
            child: _Circle(choice: right, onTap: () => _openRight(context)),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context) => unawaited(_pick(context, ref, left));

  void _openRight(BuildContext context) =>
      unawaited(_pick(context, ref, right));
}

class _CrossGap extends StatelessWidget {
  const _CrossGap({this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    if (vertical) {
      return const SizedBox(
        width: 28,
        child: Center(
          child: SizedBox(
            width: 1,
            height: 120,
            child: ColoredBox(color: HomiziColors.line),
          ),
        ),
      );
    }
    return const SizedBox(
      height: 28,
      child: Center(
        child: SizedBox(
          height: 1,
          width: double.infinity,
          child: ColoredBox(color: HomiziColors.line),
        ),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.choice, required this.onTap});

  final _CircleChoice choice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = homiziText(context, choice.label);
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        key: choice.circleKey,
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      choice.image,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: HomiziColors.mist,
                        child: Icon(choice.icon, color: HomiziColors.accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: HomiziColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _pick(
  BuildContext context,
  WidgetRef ref,
  _CircleChoice choice,
) async {
  final phase = ref.read(sessionProvider).phase;
  if (phase == SessionPhase.ready || phase == SessionPhase.needsRole) {
    await ref.read(sessionProvider.notifier).selectPrimaryRole(choice.wire);
  }
  if (!context.mounted) {
    return;
  }
  unawaited(context.push(choice.path));
}
