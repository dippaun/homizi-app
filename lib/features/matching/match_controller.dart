import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_catalog.dart';

const visitSlots = <String>[
  'Saturday 11:00 AM',
  'Sunday 4:00 PM',
  'Wednesday 6:30 PM',
];

class MatchMessage {
  const MatchMessage({required this.fromSelf, required this.body});

  final bool fromSelf;
  final String body;
}

class MatchSession {
  const MatchSession({
    this.side = MatchSide.tenant,
    this.tenant = const TenantPriorities(),
    this.host = const HostPriorities(),
    this.offices = const [powaiOffice],
    this.activeOfficeId = 'powai',
    this.mode = TransportMode.car,
    this.maxMinutes = 30,
    this.signals = LearnedSignals.empty,
    this.skipped = const <String>{},
    this.liked = const <String>{},
    this.saved = const <String>{},
    this.shareContact = true,
    this.contactShared = const <String>{},
    this.documentsShared = const <String>{},
    this.visits = const <String, String>{},
    this.threads = const <String, List<MatchMessage>>{},
    this.viewer = demoViewerRoomie,
    this.feedChip = MatchFeedChip.forYou,
  });

  final MatchSide side;
  final TenantPriorities tenant;
  final HostPriorities host;
  final List<OfficePlace> offices;
  final String activeOfficeId;
  final TransportMode mode;
  final int maxMinutes;
  final LearnedSignals signals;
  final Set<String> skipped;
  final Set<String> liked;
  final Set<String> saved;
  final bool shareContact;
  final Set<String> contactShared;
  final Set<String> documentsShared;
  final Map<String, String> visits;
  final Map<String, List<MatchMessage>> threads;
  final RoomieProfile viewer;
  final MatchFeedChip feedChip;

  OfficePlace get activeOffice {
    for (final office in offices) {
      if (office.id == activeOfficeId) {
        return office;
      }
    }
    return offices.first;
  }

  CommuteContext get commute =>
      CommuteContext(office: activeOffice, mode: mode, maxMinutes: maxMinutes);

  MatchSession copyWith({
    MatchSide? side,
    TenantPriorities? tenant,
    HostPriorities? host,
    List<OfficePlace>? offices,
    String? activeOfficeId,
    TransportMode? mode,
    int? maxMinutes,
    LearnedSignals? signals,
    Set<String>? skipped,
    Set<String>? liked,
    Set<String>? saved,
    bool? shareContact,
    Set<String>? contactShared,
    Set<String>? documentsShared,
    Map<String, String>? visits,
    Map<String, List<MatchMessage>>? threads,
    RoomieProfile? viewer,
    MatchFeedChip? feedChip,
  }) {
    return MatchSession(
      side: side ?? this.side,
      tenant: tenant ?? this.tenant,
      host: host ?? this.host,
      offices: offices ?? this.offices,
      activeOfficeId: activeOfficeId ?? this.activeOfficeId,
      mode: mode ?? this.mode,
      maxMinutes: maxMinutes ?? this.maxMinutes,
      signals: signals ?? this.signals,
      skipped: skipped ?? this.skipped,
      liked: liked ?? this.liked,
      saved: saved ?? this.saved,
      shareContact: shareContact ?? this.shareContact,
      contactShared: contactShared ?? this.contactShared,
      documentsShared: documentsShared ?? this.documentsShared,
      visits: visits ?? this.visits,
      threads: threads ?? this.threads,
      viewer: viewer ?? this.viewer,
      feedChip: feedChip ?? this.feedChip,
    );
  }
}

class MatchController extends Notifier<MatchSession> {
  @override
  MatchSession build() {
    ref.keepAlive();
    return const MatchSession();
  }

  void setSide(MatchSide side) {
    state = state.copyWith(side: side);
  }

  void setChip(MatchFeedChip chip) {
    state = state.copyWith(feedChip: chip);
  }

  void reorderTenant(int oldIndex, int newIndex) {
    state = state.copyWith(tenant: state.tenant.reorder(oldIndex, newIndex));
  }

  void reorderHost(int oldIndex, int newIndex) {
    state = state.copyWith(host: state.host.reorder(oldIndex, newIndex));
  }

  void toggleTenantMust(TenantFactorId id) {
    state = state.copyWith(tenant: state.tenant.toggleMust(id));
  }

  void toggleHostMust(HostFactorId id) {
    state = state.copyWith(host: state.host.toggleMust(id));
  }

  void addTenantFactor(TenantFactorId id) {
    state = state.copyWith(tenant: state.tenant.addFactor(id));
  }

  void removeTenantFactor(TenantFactorId id) {
    state = state.copyWith(tenant: state.tenant.removeFactor(id));
  }

  void prioritizeCommute() {
    state = state.copyWith(tenant: state.tenant.prioritizeCommute());
  }

  void setMode(TransportMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setMaxMinutes(int minutes) {
    state = state.copyWith(maxMinutes: minutes);
  }

  void setActiveOffice(String id) {
    state = state.copyWith(activeOfficeId: id);
  }

  void addOffice(String id) {
    if (state.offices.any((office) => office.id == id)) {
      state = state.copyWith(activeOfficeId: id);
      return;
    }
    OfficePlace? preset;
    for (final office in presetOffices) {
      if (office.id == id) {
        preset = office;
      }
    }
    if (preset == null) {
      return;
    }
    state = state.copyWith(
      offices: [...state.offices, preset],
      activeOfficeId: preset.id,
    );
  }

  void setShareContact(bool value) {
    state = state.copyWith(shareContact: value);
  }

  List<MatchCardModel> cards() {
    final ranked = state.side == MatchSide.tenant
        ? tenantMatchCards(
            priorities: state.tenant,
            commute: state.commute,
            signals: state.signals,
          )
        : hostMatchCards(
            priorities: state.host,
            commute: state.commute,
            viewer: state.viewer,
            signals: state.signals,
          );
    return filterMatchCards(
      ranked,
      state.feedChip,
      maxMinutes: state.maxMinutes,
    );
  }

  List<MatchCardModel> deck() {
    final ranked = state.side == MatchSide.tenant
        ? tenantMatchCards(
            priorities: state.tenant,
            commute: state.commute,
            signals: state.signals,
          )
        : hostMatchCards(
            priorities: state.host,
            commute: state.commute,
            viewer: state.viewer,
            signals: state.signals,
          );
    return [
      for (final card in ranked)
        if (!state.skipped.contains(card.id) && !state.liked.contains(card.id))
          card,
    ];
  }

  MatchCardModel? card(String id) {
    return matchCardById(
      id: id,
      side: state.side,
      tenant: state.tenant,
      host: state.host,
      commute: state.commute,
      viewer: state.viewer,
      signals: state.signals,
    );
  }

  void skip(String id) {
    final current = card(id);
    final signals = current == null
        ? state.signals
        : signalsAfterDecision(state.signals, current.breakdown, liked: false);
    state = state.copyWith(skipped: {...state.skipped, id}, signals: signals);
  }

  void toggleSave(String id) {
    final next = {...state.saved};
    final added = next.add(id);
    if (!added) {
      next.remove(id);
    }
    final current = card(id);
    final signals = !added || current == null
        ? state.signals
        : signalsAfterDecision(state.signals, current.breakdown, liked: true);
    state = state.copyWith(saved: next, signals: signals);
  }

  /// True when the other side was already interested.
  bool like(String id) {
    final current = card(id);
    final signals = current == null
        ? state.signals
        : signalsAfterDecision(state.signals, current.breakdown, liked: true);
    state = state.copyWith(liked: {...state.liked, id}, signals: signals);
    return current?.reciprocal ?? false;
  }

  void resetSignals() {
    state = state.copyWith(signals: LearnedSignals.empty);
  }

  void shareContactWith(String id) {
    state = state.copyWith(contactShared: {...state.contactShared, id});
  }

  void shareDocumentsWith(String id) {
    state = state.copyWith(documentsShared: {...state.documentsShared, id});
  }

  void bookVisit(String id, String slot) {
    state = state.copyWith(visits: {...state.visits, id: slot});
  }

  List<MatchMessage> messagesFor(String id) {
    final existing = state.threads[id];
    if (existing != null) {
      return existing;
    }
    return const [
      MatchMessage(fromSelf: false, body: "Hi! I'm interested in this room."),
      MatchMessage(
        fromSelf: false,
        body: "Yes, it's available. Would you like to schedule a visit?",
      ),
    ];
  }

  void send(String id, String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final safe = displayMessageBody(trimmed);
    final next = [...messagesFor(id), MatchMessage(fromSelf: true, body: safe)];
    state = state.copyWith(threads: {...state.threads, id: next});
  }
}

final matchControllerProvider = NotifierProvider<MatchController, MatchSession>(
  MatchController.new,
);
