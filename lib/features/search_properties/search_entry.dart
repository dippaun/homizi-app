import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/account_prompt.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/explore/explore_gateway.dart';
import 'package:homizi/features/explore/explore_providers.dart';
import 'package:homizi/features/personalize/personalization.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/search_properties/search_draft.dart';
import 'package:homizi/features/search_properties/search_persist.dart';
import 'package:homizi/features/search_properties/search_properties_screen.dart';
import 'package:homizi/features/search_properties/search_rank.dart';
import 'package:homizi/features/search_properties/search_store.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';

/// Search tab and other entry points.
///
/// Tenants with a saved search go to Your best matches. The wizard shows
/// the first time, or when [editing] reopens it. Every other role sees a
/// prompt to continue as a tenant.
class SearchEntry extends ConsumerStatefulWidget {
  const SearchEntry({super.key, this.editing = false});

  final bool editing;

  @override
  ConsumerState<SearchEntry> createState() => _SearchEntryState();
}

class _SearchEntryState extends ConsumerState<SearchEntry> {
  PropertySearch? _saved;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    if (_tenant) {
      unawaited(_open());
    }
  }

  bool get _tenant => ref.read(currentRoleProvider) == HomiziRole.tenant;

  Future<void> _open() async {
    final saved = await loadEntrySearch(
      store: ref.read(propertySearchStoreProvider),
      gateway: _gateway(),
      personal: ref.read(personalizationProvider),
      tenant: await _tenantPreferences(),
    );
    if (!mounted) {
      return;
    }
    if (saved != null && !widget.editing) {
      ref.read(shownPropertySearchProvider.notifier).replace(saved);
      ref.invalidate(savedPropertySearchProvider);
      await _rank(saved);
      if (!mounted) {
        return;
      }
      context.go(RoutePaths.searchMatches);
      return;
    }
    setState(() {
      _saved = saved;
      _ready = true;
    });
  }

  ExploreGateway? _gateway() {
    try {
      return ref.read(exploreGatewayProvider);
    } on Object {
      return null;
    }
  }

  Future<TenantPreferences?> _tenantPreferences() async {
    try {
      final profile = await ref
          .read(accountGatewayProvider)
          .loadTenantProfile();
      return profile.preferences;
    } on Object {
      return null;
    }
  }

  Future<void> _rank(PropertySearch search) async {
    try {
      ref
          .read(listingFilterProvider.notifier)
          .replace(search.toListingFilters());
      var listings = ref.read(discoveryProvider).listings;
      if (listings.isEmpty) {
        await ref.read(discoveryProvider.notifier).refresh();
        listings = ref.read(discoveryProvider).listings;
      }
      ref
          .read(rankedHomesProvider.notifier)
          .replace(rankHomes(listings: listings, search: search));
    } on Object {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(currentRoleProvider);
    if (role != HomiziRole.tenant) {
      return const SearchTenantPrompt();
    }
    // Edit waits for the saved draft so the fields open filled in. A normal
    // visit shows the wizard immediately and leaves it if nothing is saved.
    if (widget.editing && !_ready) {
      return const Scaffold(
        key: Key('search-entry-loading'),
        backgroundColor: HomiziColors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return SearchPropertiesScreen(initial: _ready ? _saved : null);
  }
}

/// Shown when Search Properties is opened by anyone who is not a tenant.
class SearchTenantPrompt extends ConsumerWidget {
  const SearchTenantPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    return Scaffold(
      key: const Key('search-tenant-prompt'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HomiziColors.white,
        surfaceTintColor: HomiziColors.white,
        leading: const HomiziBackButton(),
        title: const Text('Search Properties'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          const Text(
            'Search Properties is for tenants.',
            style: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: HomiziColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pick the Tenant role to set what you need. Homizi then keeps that search and opens your matches next time.',
            style: TextStyle(color: HomiziColors.inkSoft, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('search-pick-tenant'),
            onPressed: () => unawaited(_pick(context, ref, signedIn: signedIn)),
            child: Text(
              signedIn ? 'Continue as a tenant' : 'Sign in as a tenant',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref, {
    required bool signedIn,
  }) async {
    if (!signedIn) {
      unawaited(context.push(signInReturn(RoutePaths.searchStart)));
      return;
    }
    final error = await ref
        .read(sessionProvider.notifier)
        .selectPrimaryRole(homiziRoleWire(HomiziRole.tenant));
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    context.go(RoutePaths.searchStart);
  }
}
