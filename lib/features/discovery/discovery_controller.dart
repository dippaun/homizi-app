import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/core/supabase/live_social.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final discoveryProvider = NotifierProvider<DiscoveryController, DiscoveryState>(
  DiscoveryController.new,
);

class DiscoveryController extends Notifier<DiscoveryState> {
  Timer? _liveRefresh;
  StreamSubscription<void>? _live;

  @override
  DiscoveryState build() {
    ref.onDispose(() {
      _liveRefresh?.cancel();
      unawaited(_live?.cancel());
    });
    final gateway = ref.watch(discoveryGatewayProvider);
    // Signing in or out swaps guest sample homes for Supabase homes.
    ref.watch(sessionProvider.select((session) => session.userId));
    _bindLive();
    final published = ref.watch(publishedSearchProvider);
    final cached = gateway.cachedOrNull;
    if (cached != null) {
      return withPublishedHomes(cached, published);
    }
    unawaited(Future<void>.microtask(refresh));
    return const DiscoveryState(loading: true);
  }

  void _bindLive() {
    unawaited(_live?.cancel());
    _live = null;
    final config = ref.read(appConfigProvider);
    final forceDemo = ref.read(forceDemoModeProvider);
    final session = ref.read(sessionProvider);
    final signedIn =
        session.phase == SessionPhase.ready &&
        session.userId != null &&
        session.userId!.isNotEmpty;
    if (!config.connectsToSupabase || forceDemo || !signedIn) {
      return;
    }
    try {
      _live = openLiveSocialChanges(
        Supabase.instance.client,
      ).listen((_) => _scheduleLiveRefresh(), onError: (_) {});
    } on Object {
      _live = null;
    }
  }

  void _scheduleLiveRefresh() {
    _liveRefresh?.cancel();
    _liveRefresh = Timer(const Duration(milliseconds: 400), () {
      if (ref.mounted) {
        unawaited(_refresh(silent: true));
      }
    });
  }

  Future<void> refresh() => _refresh();

  Future<void> _refresh({bool silent = false}) async {
    final gateway = ref.read(discoveryGatewayProvider);
    if (!silent) {
      state = state.copyWith(loading: true, clearError: true);
    }
    try {
      final next = await gateway.load();
      if (!ref.mounted) {
        return;
      }
      state = withPublishedHomes(next, ref.read(publishedSearchProvider));
    } on DiscoveryFailure catch (error) {
      if (!ref.mounted || silent) {
        return;
      }
      state = state.copyWith(
        loading: false,
        error: userFacingError(error.message),
      );
    } catch (error) {
      if (!ref.mounted || silent) {
        return;
      }
      state = state.copyWith(loading: false, error: describedFailure(error));
    }
  }

  Future<DiscoveryNotice> like(String listingId) async {
    final notice = await _act(
      listingId,
      (gateway, listing) => gateway.likeListing(listing),
    );
    if (notice.ok) {
      unawaited(
        ref
            .read(analyticsGatewayProvider)
            .log('interest_sent', properties: {'listing_id': listingId}),
      );
    }
    return notice;
  }

  Future<DiscoveryNotice> pass(String listingId) {
    return _act(listingId, (gateway, listing) => gateway.passListing(listing));
  }

  Future<DiscoveryNotice> undo(String listingId) {
    return _act(listingId, (gateway, listing) => gateway.undoListing(listing));
  }

  Future<DiscoveryNotice> shareOwnContact(String matchId, String scope) {
    return _matchAct(
      matchId,
      (gateway) => gateway.shareOwnContact(matchId, scope),
    );
  }

  Future<DiscoveryNotice> stopSharingOwnContact(String matchId) {
    return _matchAct(
      matchId,
      (gateway) => gateway.stopSharingOwnContact(matchId),
    );
  }

  Future<DiscoveryNotice> toggleSave(String listingId) async {
    final listing = state.byId(listingId);
    if (listing == null) {
      return DiscoveryNotice.unavailable;
    }
    final saved = state.savedIds.contains(listingId);
    final gateway = ref.read(discoveryGatewayProvider);
    state = state.copyWith(busy: true);
    try {
      final message = saved
          ? await gateway.unsaveListing(listingId)
          : await gateway.saveListing(listing);
      await _replaceFrom(gateway);
      return DiscoveryNotice(message: message, ok: true);
    } on DiscoveryFailure catch (error) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
      return DiscoveryNotice(
        message: userFacingError(error.message),
        ok: false,
      );
    }
  }

  Future<DiscoveryNotice> _act(
    String listingId,
    Future<String> Function(DiscoveryGateway gateway, Listing listing) action,
  ) async {
    final listing = state.byId(listingId);
    if (listing == null) {
      return DiscoveryNotice.unavailable;
    }
    final gateway = ref.read(discoveryGatewayProvider);
    state = state.copyWith(busy: true);
    try {
      final message = await action(gateway, listing);
      await _replaceFrom(gateway);
      return DiscoveryNotice(message: message, ok: true);
    } on DiscoveryFailure catch (error) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
      return DiscoveryNotice(
        message: userFacingError(error.message),
        ok: false,
      );
    }
  }

  Future<DiscoveryNotice> _matchAct(
    String matchId,
    Future<String> Function(DiscoveryGateway gateway) action,
  ) async {
    final known = state.matches.any((match) => match.matchId == matchId);
    if (!known) {
      return const DiscoveryNotice(
        message: 'That match is not available.',
        ok: false,
      );
    }
    final gateway = ref.read(discoveryGatewayProvider);
    state = state.copyWith(busy: true);
    try {
      final message = await action(gateway);
      await _replaceFrom(gateway);
      return DiscoveryNotice(message: message, ok: true);
    } on DiscoveryFailure catch (error) {
      if (ref.mounted) {
        state = state.copyWith(busy: false);
      }
      return DiscoveryNotice(
        message: userFacingError(error.message),
        ok: false,
      );
    }
  }

  Future<void> _replaceFrom(DiscoveryGateway gateway) async {
    final cached = gateway.cachedOrNull;
    final next = cached ?? await gateway.load();
    if (!ref.mounted) {
      return;
    }
    state = withPublishedHomes(next, ref.read(publishedSearchProvider));
  }

  /// Like without reloading the feed. The heart of the swipe deck updates
  /// before this future completes; a failed write puts the id back.
  Future<DiscoveryNotice> likeNow(Listing listing) {
    final id = listing.id;
    return _fast(
      listing: listing,
      apply: (current) => current.copyWith(likedIds: {...current.likedIds, id}),
      undo: (current) =>
          current.copyWith(likedIds: {...current.likedIds}..remove(id)),
      action: (gateway, item) => gateway.likeListing(item),
      event: 'interest_sent',
    );
  }

  Future<DiscoveryNotice> passNow(Listing listing) {
    final id = listing.id;
    final wasLiked = state.likedIds.contains(id);
    return _fast(
      listing: listing,
      apply: (current) =>
          current.copyWith(likedIds: {...current.likedIds}..remove(id)),
      undo: (current) => current.copyWith(
        likedIds: wasLiked ? {...current.likedIds, id} : {...current.likedIds}
          ..remove(id),
      ),
      action: (gateway, item) => gateway.passListing(item),
    );
  }

  Future<DiscoveryNotice> saveNow(Listing listing) {
    final id = listing.id;
    if (state.savedIds.contains(id)) {
      return Future<DiscoveryNotice>.value(
        const DiscoveryNotice(message: DiscoveryCopy.serverSave, ok: true),
      );
    }
    return _fast(
      listing: listing,
      apply: (current) => current.copyWith(savedIds: {...current.savedIds, id}),
      undo: (current) =>
          current.copyWith(savedIds: {...current.savedIds}..remove(id)),
      action: (gateway, item) => gateway.saveListing(item),
    );
  }

  Future<DiscoveryNotice> toggleSaveNow(Listing listing) {
    final id = listing.id;
    final wasSaved = state.savedIds.contains(id);
    return _fast(
      listing: listing,
      apply: (current) {
        final next = {...current.savedIds};
        if (wasSaved) {
          next.remove(id);
        } else {
          next.add(id);
        }
        return current.copyWith(savedIds: next);
      },
      undo: (current) {
        final next = {...current.savedIds};
        if (wasSaved) {
          next.add(id);
        } else {
          next.remove(id);
        }
        return current.copyWith(savedIds: next);
      },
      action: (gateway, item) =>
          wasSaved ? gateway.unsaveListing(id) : gateway.saveListing(item),
    );
  }

  Future<DiscoveryNotice> _fast({
    required Listing listing,
    required DiscoveryState Function(DiscoveryState current) apply,
    required DiscoveryState Function(DiscoveryState current) undo,
    required Future<String> Function(DiscoveryGateway gateway, Listing listing)
    action,
    String? event,
  }) async {
    if (listing.id.isEmpty) {
      return DiscoveryNotice.unavailable;
    }
    state = apply(state);
    final gateway = ref.read(discoveryGatewayProvider);
    try {
      final message = await action(gateway, listing);
      if (ref.mounted) {
        final cached = gateway.cachedOrNull;
        if (cached != null) {
          final current = state;
          state = withPublishedHomes(cached, ref.read(publishedSearchProvider))
              .copyWith(
                likedIds: {...cached.likedIds, ...current.likedIds},
                savedIds: {...cached.savedIds, ...current.savedIds},
              );
        }
        if (event != null) {
          unawaited(
            ref
                .read(analyticsGatewayProvider)
                .log(event, properties: {'listing_id': listing.id}),
          );
        }
      }
      return DiscoveryNotice(message: message, ok: true);
    } on DiscoveryFailure catch (error) {
      if (ref.mounted) {
        state = undo(state);
      }
      return DiscoveryNotice(
        message: userFacingError(error.message),
        ok: false,
      );
    } catch (error) {
      if (ref.mounted) {
        state = undo(state);
      }
      return DiscoveryNotice(message: describedFailure(error), ok: false);
    }
  }
}
