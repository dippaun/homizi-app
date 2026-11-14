import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/find_roomie/find_roomie_catalog.dart';
import 'package:homizi/features/find_roomie/find_roomie_gateway.dart';
import 'package:homizi/features/find_roomie/find_roomie_models.dart';
import 'package:homizi/features/find_roomie/find_roomie_store.dart';
import 'package:homizi/features/roommates/domain/roommate_seeker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final findRoomieLocalProvider = Provider<FindRoomieLocal>((ref) {
  return DeviceFindRoomieLocal();
});

final findRoomieGatewayProvider = Provider<FindRoomieGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final demo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || demo) {
    return const SampleFindRoomieGateway();
  }
  return SupabaseFindRoomieGateway(Supabase.instance.client);
});

class FindRoomieState {
  const FindRoomieState({
    required this.loading,
    required this.deck,
    required this.links,
    required this.shortlists,
    required this.joints,
  });

  final bool loading;
  final FindRoomieDeck deck;
  final List<FindRoomieLink> links;
  final List<FindRoomieShortlist> shortlists;
  final List<FindRoomieJoint> joints;

  factory FindRoomieState.loading() {
    return FindRoomieState(
      loading: true,
      deck: sampleFindRoomieDeck(),
      links: const [],
      shortlists: const [],
      joints: const [],
    );
  }

  bool get sample => deck.sample;

  RoommateSeeker? person(String id) => deck.person(id);

  FindRoomieLink? linkFor(String personId) {
    for (final link in links) {
      if (link.personId == personId) {
        return link;
      }
    }
    return null;
  }

  (String, String) pairFor(String personId) {
    final partner = person(personId)?.id ?? personId;
    return orderedMembers(deck.viewerId, partner);
  }

  bool shortlisted(String personId, String listingId) {
    final pair = pairFor(personId);
    for (final row in shortlists) {
      if (row.memberA == pair.$1 &&
          row.memberB == pair.$2 &&
          row.listingId == listingId) {
        return true;
      }
    }
    return false;
  }

  FindRoomieJoint? jointFor(String personId, String listingId) {
    final pair = pairFor(personId);
    for (final row in joints) {
      if (row.memberA == pair.$1 &&
          row.memberB == pair.$2 &&
          row.listingId == listingId) {
        return row;
      }
    }
    return null;
  }

  FindRoomieState copyWith({
    bool? loading,
    FindRoomieDeck? deck,
    List<FindRoomieLink>? links,
    List<FindRoomieShortlist>? shortlists,
    List<FindRoomieJoint>? joints,
  }) {
    return FindRoomieState(
      loading: loading ?? this.loading,
      deck: deck ?? this.deck,
      links: links ?? this.links,
      shortlists: shortlists ?? this.shortlists,
      joints: joints ?? this.joints,
    );
  }
}

final findRoomieProvider =
    NotifierProvider<FindRoomieController, FindRoomieState>(
      FindRoomieController.new,
    );

class FindRoomieController extends Notifier<FindRoomieState> {
  @override
  FindRoomieState build() {
    Future.microtask(load);
    return FindRoomieState.loading();
  }

  Future<void> load() async {
    final gateway = ref.read(findRoomieGatewayProvider);
    final saved = await ref.read(findRoomieLocalProvider).read();
    final deck = await gateway.loadSeekers();
    if (!ref.mounted) {
      return;
    }
    final remoteShort = await gateway.shortlists();
    final remoteJoints = await gateway.joints();
    if (!ref.mounted) {
      return;
    }
    state = state.copyWith(
      loading: false,
      deck: deck,
      links: _mergeLinks(saved.links, state.links),
      shortlists: _mergeShort(
        remoteShort ?? saved.shortlists,
        state.shortlists,
      ),
      joints: _mergeJoints(remoteJoints ?? saved.joints, state.joints),
    );
  }

  Future<String> connect(String personId) async {
    final existing = state.linkFor(personId);
    if (existing != null) {
      return existing.matchId;
    }
    final person = state.person(personId);
    if (person == null) {
      return '';
    }
    final result = await ref.read(findRoomieGatewayProvider).connect(person);
    if (!ref.mounted) {
      return result.matchId;
    }
    final links = [
      ...state.links.where((link) => link.personId != personId),
      FindRoomieLink(
        personId: personId,
        matchId: result.matchId,
        fromServer: result.fromServer,
      ),
    ];
    state = state.copyWith(links: links);
    await _persist();
    return result.matchId;
  }

  Future<void> saveHome(String personId, String listingId) async {
    if (state.shortlisted(personId, listingId)) {
      return;
    }
    final pair = state.pairFor(personId);
    final link = state.linkFor(personId);
    final row = FindRoomieShortlist(
      memberA: pair.$1,
      memberB: pair.$2,
      listingId: listingId,
      matchId: link != null && link.fromServer ? link.matchId : null,
    );
    state = state.copyWith(shortlists: [...state.shortlists, row]);
    await _persist();
    await ref.read(findRoomieGatewayProvider).saveShortlist(row);
  }

  Future<void> confirmSelf(String personId, String listingId) async {
    await _confirm(personId, listingId, state.deck.viewerId);
  }

  /// Device-only. The other person confirms on their own account once the
  /// table exists. Sample mode records it here so the flow can finish.
  Future<void> confirmPartnerOnDevice(String personId, String listingId) async {
    if (!state.sample) {
      return;
    }
    final partner = state.person(personId);
    if (partner == null) {
      return;
    }
    await _confirm(personId, listingId, partner.id);
  }

  Future<void> _confirm(
    String personId,
    String listingId,
    String userId,
  ) async {
    final pair = state.pairFor(personId);
    final link = state.linkFor(personId);
    final current =
        state.jointFor(personId, listingId) ??
        FindRoomieJoint(
          memberA: pair.$1,
          memberB: pair.$2,
          listingId: listingId,
          aConfirmed: false,
          bConfirmed: false,
          matchId: link != null && link.fromServer ? link.matchId : null,
        );
    final next = confirmMember(current, userId, value: true);
    final joints = [
      for (final row in state.joints)
        if (!_sameJoint(row, next)) row,
      next,
    ];
    state = state.copyWith(joints: joints);
    await _persist();
    if (userId == state.deck.viewerId) {
      await ref.read(findRoomieGatewayProvider).saveJoint(next);
    }
  }

  Future<void> _persist() async {
    await ref
        .read(findRoomieLocalProvider)
        .write(
          FindRoomieSnapshot(
            links: state.links,
            shortlists: state.shortlists,
            joints: state.joints,
          ),
        );
  }
}

List<FindRoomieLink> _mergeLinks(
  List<FindRoomieLink> base,
  List<FindRoomieLink> extra,
) {
  final known = {for (final link in base) link.personId};
  return [
    ...base,
    for (final link in extra)
      if (!known.contains(link.personId)) link,
  ];
}

List<FindRoomieShortlist> _mergeShort(
  List<FindRoomieShortlist> base,
  List<FindRoomieShortlist> extra,
) {
  bool same(FindRoomieShortlist row, FindRoomieShortlist other) {
    return row.memberA == other.memberA &&
        row.memberB == other.memberB &&
        row.listingId == other.listingId;
  }

  return [
    ...base,
    for (final row in extra)
      if (!base.any((item) => same(item, row))) row,
  ];
}

List<FindRoomieJoint> _mergeJoints(
  List<FindRoomieJoint> base,
  List<FindRoomieJoint> extra,
) {
  final merged = [...base];
  for (final row in extra) {
    final index = merged.indexWhere((item) => _sameJoint(item, row));
    if (index == -1) {
      merged.add(row);
    } else if (row.aConfirmed || row.bConfirmed) {
      merged[index] = row;
    }
  }
  return merged;
}

bool _sameJoint(FindRoomieJoint row, FindRoomieJoint next) {
  return row.memberA == next.memberA &&
      row.memberB == next.memberB &&
      row.listingId == next.listingId;
}
