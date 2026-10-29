import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';

/// Tenant start: full room, shared room, or a roommate, then requirements.
class TenantKindScreen extends ConsumerWidget {
  const TenantKindScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stay = ref.watch(flowPrefsProvider).stay;
    return Scaffold(
      key: const Key('tenant-kind-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Tenant')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                homiziText(context, 'What are you looking for?'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: HomiziColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(
                  context,
                  'Pick one. You can change budget, location, amenities, and preferences on the next step.',
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: HomiziColors.inkSoft,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              _StayTile(
                tileKey: const Key('tenant-stay-full'),
                title: 'Full room',
                detail: 'A private room or a whole flat in Bengaluru, Mumbai, or your city.',
                icon: Icons.meeting_room_outlined,
                selected: stay == 'full',
                onTap: () => _choose(ref, 'full'),
              ),
              const SizedBox(height: 12),
              _StayTile(
                tileKey: const Key('tenant-stay-shared'),
                title: 'Shared room',
                detail: 'Share a room in a flat or a PG. Rent is split.',
                icon: Icons.bed_outlined,
                selected: stay == 'shared',
                onTap: () => _choose(ref, 'shared'),
              ),
              const SizedBox(height: 12),
              _StayTile(
                tileKey: const Key('tenant-stay-roommate'),
                title: 'Roommate',
                detail: 'A home you can share. People matching stays in Find Your Roomie.',
                icon: Icons.groups_outlined,
                selected: stay == 'roommate',
                onTap: () => _choose(ref, 'roommate'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('tenant-kind-continue'),
                onPressed: () => context.push(RoutePaths.flowRequirements),
                child: Text(homiziText(context, 'Enter requirements')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _choose(WidgetRef ref, String stay) {
    ref.read(flowPrefsProvider.notifier).update(
      ref.read(flowPrefsProvider).copyWith(stay: stay),
    );
  }
}

class _StayTile extends StatelessWidget {
  const _StayTile({
    required this.tileKey,
    required this.title,
    required this.detail,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final Key tileKey;
  final String title;
  final String detail;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      shadowColor: HomiziColors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        key: tileKey,
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: HomiziColors.shadowSoft,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
            color: selected ? HomiziColors.accent : HomiziColors.white,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: selected ? HomiziColors.ink : HomiziColors.accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homiziText(context, title),
                        style: const TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: HomiziColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        homiziText(context, detail),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          height: 1.35,
                          color: HomiziColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
