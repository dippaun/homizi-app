import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/analytics/analytics_providers.dart';
import 'package:homizi/features/discovery/discovery_gateway.dart';
import 'package:homizi/features/discovery/discovery_providers.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/discovery/domain/listing.dart';

final discoveryProvider = NotifierProvider<DiscoveryController, DiscoveryState>(
  DiscoveryController.new,
);

class DiscoveryController extends Notifier<DiscoveryState> {
  @override
  DiscoveryState build() {
    final gateway = ref.watch(discoveryGatewayProvider);
    final cached = gateway.cachedOrNull;
    if (cached != null) {
      return cached;
    }
    unawaited(Future<void>.microtask(refresh));
    return const DiscoveryState(loading: true);
  }

  Future<void> refresh() async {
    final gateway = ref.read(discoveryGatewayProvider);
    state = state.copyWith(loading: true, clearError: true);
    try {
      final next = await gateway.load();
      if (!ref.mounted) {
        return;
      }
      state = next;
    } on DiscoveryFailure catch (error) {
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(loading: false, error: error.message);
    } catch (error) {
      if (!ref.mounted) {
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
      return DiscoveryNotice(message: error.message, ok: false);
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
      return DiscoveryNotice(message: error.message, ok: false);
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
      return DiscoveryNotice(message: error.message, ok: false);
    }
  }

  Future<void> _replaceFrom(DiscoveryGateway gateway) async {
    final cached = gateway.cachedOrNull;
    final next = cached ?? await gateway.load();
    if (!ref.mounted) {
      return;
    }
    state = next;
  }
}
