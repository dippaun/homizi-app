import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/routing/sign_in_gate.dart';
import 'package:homizi/core/storage/storage_key.dart';
import 'package:homizi/core/storage/user_scope.dart';
import 'package:homizi/features/auth/registration_gate.dart';
import 'package:homizi/features/chat/opened_direct_chats.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/listing_match_providers.dart';
import 'package:homizi/features/explore/explore_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_providers.dart';
import 'package:homizi/features/host/host_onboarding_store.dart';
import 'package:homizi/features/listings/listing_draft_controller.dart';
import 'package:homizi/features/matching/match_controller.dart';
import 'package:homizi/features/matching/priority_keys.dart';
import 'package:homizi/features/more/more_requests.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/owner/demo_listing_memory.dart';
import 'package:homizi/features/owner/owner_dashboard_screen.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/post_property/owner_extras.dart';
import 'package:homizi/features/post_property/partner_application.dart';
import 'package:homizi/features/post_property/post_contact.dart';
import 'package:homizi/features/priorities/priority_preferences.dart';
import 'package:homizi/features/priorities/priority_store.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/publish/published_activity.dart';
import 'package:homizi/features/roles/role_setup.dart';
import 'package:homizi/features/roommates/finder/finder_controller.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';
import 'package:homizi/features/search_properties/search_store.dart';
import 'package:homizi/features/seekers/seeker_shortlist.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/shared_home/shared_home_providers.dart';
import 'package:homizi/features/tools/domain/smart_move.dart';
import 'package:homizi/features/tools/rent_split/rent_split_repository.dart';
import 'package:homizi/features/verification/kyc_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Watches the auth user and drops the previous account's memory.
final sessionIsolationProvider = Provider<void>((ref) {
  ref.listen(sessionProvider.select((session) => session.userId), (
    previous,
    next,
  ) {
    if (previous == next) {
      return;
    }
    bindStorageUser(next);
    ref.read(registrationBypassProvider.notifier).reset();
    if (next == null) {
      ref.read(signInReturnPathProvider.notifier).clear();
    }
    resetUserCaches(ref);
    unawaited(_settleScope(ref, next));
  });
});

Future<void> _settleScope(Ref ref, String? uid) async {
  if (uid != null && uid.isNotEmpty) {
    await UserScope.migrateGuestIfEmpty(
      uid: uid,
      accountHasSaves: () => accountHasSavedData(uid),
    );
  }
  if (!ref.mounted) {
    return;
  }
  resetUserCaches(ref);
}

/// Drops keep-alive controllers, static ranks, and provider caches.
void resetUserCaches(Ref ref) {
  SavedRanks.tenant = null;
  SavedRanks.host = null;
  SmartMoveInterestStore.instance.clear();
  ref
    ..invalidate(searchPrioritiesProvider)
    ..invalidate(hostTenantPrioritiesProvider)
    ..invalidate(priorityStateProvider)
    ..invalidate(prioritySyncProvider)
    ..invalidate(personalizationProvider)
    ..invalidate(roleSetupProvider)
    ..invalidate(savedPropertySearchProvider)
    ..invalidate(shownPropertySearchProvider)
    ..invalidate(roomieProvider)
    ..invalidate(findRoomieProvider)
    ..invalidate(findRoomieLocalProvider)
    ..invalidate(occupancyNeedProvider)
    ..invalidate(joinRequestsProvider)
    ..invalidate(sharedHomeRepositoryProvider)
    ..invalidate(sharedHomeDetailsProvider)
    ..invalidate(matchControllerProvider)
    ..invalidate(discoveryProvider)
    ..invalidate(discoveryGatewayProvider)
    ..invalidate(listingFilterProvider)
    ..invalidate(seekerDeckProvider)
    ..invalidate(officeRepositoryProvider)
    ..invalidate(officeRevisionProvider)
    ..invalidate(profileCreateStoreProvider)
    ..invalidate(recentlyViewedProvider)
    ..invalidate(recentSearchesProvider)
    ..invalidate(savedSearchesProvider)
    ..invalidate(savedRequirementProvider)
    ..invalidate(myKycProvider)
    ..invalidate(moreRequestProvider)
    ..invalidate(partnerApplicationProvider)
    ..invalidate(rentSplitRepositoryProvider)
    ..invalidate(listingDraftProvider)
    ..invalidate(flowPrefsProvider)
    ..invalidate(hostOnboardingProvider)
    ..invalidate(ownerListingsProvider)
    ..invalidate(demoListingMemoryProvider)
    ..invalidate(publishedActivityProvider)
    ..invalidate(ownVerificationProvider)
    ..invalidate(openedDirectChatsProvider)
    ..invalidate(profileMediaProvider)
    ..invalidate(postContactProvider)
    ..invalidate(ownerDocsProvider)
    ..invalidate(finderProvider);
}

/// True when [uid] already has a profile, priorities, or saved searches.
/// Null when the check could not reach the server.
Future<bool?> accountHasSavedData(String uid) async {
  final SupabaseClient client;
  try {
    client = Supabase.instance.client;
  } on Object {
    return null;
  }
  try {
    final profile = await client
        .from('profiles')
        .select('display_name, primary_role')
        .eq('user_id', uid)
        .maybeSingle();
    if (profile != null) {
      final name = (profile['display_name'] ?? '').toString().trim();
      final role = (profile['primary_role'] ?? '').toString().trim();
      if (name.length >= 2 || role.isNotEmpty) {
        return true;
      }
    }
    for (final table in const [
      'priority_preferences',
      'saved_searches',
      'recent_searches',
    ]) {
      try {
        final rows = await client
            .from(table)
            .select('user_id')
            .eq('user_id', uid)
            .limit(1);
        if (rows.isNotEmpty) {
          return true;
        }
      } on Object {
        // A missing table does not count as saved data.
      }
    }
    return false;
  } on Object {
    return null;
  }
}
