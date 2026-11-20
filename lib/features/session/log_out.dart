import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/storage/device_string_store.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/find_roomie/find_roomie_store.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/priorities/priority_store.dart';
import 'package:homizi/features/profile_create/profile_create_draft.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/roles/role_setup.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/finder/roommate_ask.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/search_properties/search_store.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shared_home/shared_home_repository.dart';

const _sessionCacheKeys = <String>[
  propertySearchPreferenceKey,
  tenantPrioritiesKey,
  hostPrioritiesKey,
  roommateAskStoreKey,
  roommateHiddenStoreKey,
  officePreferenceKey,
  findRoomieStoreKey,
  roleSetupPreferenceKey,
  occupancyNeedKey,
  joinRequestsKey,
  sharedHomeDetailsKey,
  'flutter.homizi.profile_place',
];

/// The only Log out control. Confirms, signs out of Supabase, drops the
/// on-device session and saved preferences, then opens signed-out Home.
Future<void> confirmLogOut(BuildContext context, WidgetRef ref) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        key: const Key('log-out-confirm'),
        backgroundColor: HomiziColors.white,
        title: Text(
          homiziText(context, 'Log out?'),
          style: const TextStyle(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          homiziText(
            context,
            'You will leave this account on this device. Saved preferences on this device are cleared.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              homiziText(context, 'Cancel'),
              style: const TextStyle(color: HomiziColors.ink),
            ),
          ),
          TextButton(
            key: const Key('log-out-confirm-yes'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              homiziText(context, 'Log out'),
              style: const TextStyle(
                color: HomiziColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
    },
  );
  if (leave != true || !context.mounted) {
    return;
  }
  final router = GoRouter.of(context);
  await ref.read(sessionProvider.notifier).signOut();
  await _clearLocalCache(ref);
  router.go(RoutePaths.home);
}

Future<void> _clearLocalCache(WidgetRef ref) async {
  try {
    await ref.read(propertySearchStoreProvider).clear();
  } on Object {
    // The device copy is removed by the key wipe below.
  }
  for (final key in _sessionCacheKeys) {
    await removeDeviceString(key);
  }
  ref.read(shownPropertySearchProvider.notifier).replace(null);
  ref.invalidate(savedPropertySearchProvider);
  ref.read(profileCreateStoreProvider).draft = const ProfileCreateDraft();
  ref.read(profileMediaProvider.notifier).clear();
  ref.invalidate(searchPrioritiesProvider);
  ref.invalidate(hostTenantPrioritiesProvider);
  ref.invalidate(priorityStateProvider);
  ref.invalidate(finderProvider);
  ref.invalidate(discoveryProvider);
}

/// Red Log out row. This is the only place the action is shown.
class LogOutButton extends ConsumerWidget {
  const LogOutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('profile-log-out'),
          onPressed: () => unawaited(confirmLogOut(context, ref)),
          icon: const Icon(Icons.logout, color: HomiziColors.error),
          label: Text(
            homiziText(context, 'Log out'),
            style: const TextStyle(
              color: HomiziColors.error,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
