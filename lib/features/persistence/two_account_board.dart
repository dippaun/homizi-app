/// In-memory picture of what two signed-in accounts must see after a reload.
/// The app writes the same facts through Supabase. This board is the contract
/// the integration tests check: A's action is visible to B.
class TwoAccountBoard {
  final List<BoardLike> likes = [];
  final List<BoardSave> saves = [];
  final List<BoardDecision> decisions = [];
  final List<BoardMessage> messages = [];
  final List<BoardMatch> matches = [];

  void likeListing({
    required String actorId,
    required String hostId,
    required String listingId,
  }) {
    likes.add(
      BoardLike(
        actorId: actorId,
        targetUserId: hostId,
        targetType: 'property',
        targetId: listingId,
      ),
    );
  }

  void passListing({required String actorId, required String listingId}) {
    likes.removeWhere(
      (like) =>
          like.actorId == actorId &&
          like.targetType == 'property' &&
          like.targetId == listingId,
    );
  }

  void likePerson({required String actorId, required String otherUserId}) {
    likes.add(
      BoardLike(
        actorId: actorId,
        targetUserId: otherUserId,
        targetType: 'user',
        targetId: otherUserId,
      ),
    );
    _openMatchIfMutual(actorId, otherUserId);
  }

  void saveListing({required String actorId, required String listingId}) {
    saves.add(BoardSave(actorId: actorId, listingId: listingId));
  }

  void unsaveListing({required String actorId, required String listingId}) {
    saves.removeWhere(
      (save) => save.actorId == actorId && save.listingId == listingId,
    );
  }

  void decide({
    required String hostId,
    required String seekerId,
    required String listingId,
    required String decision,
  }) {
    if (decision != 'accepted' && decision != 'rejected') {
      throw ArgumentError('decision');
    }
    decisions.removeWhere(
      (row) =>
          row.hostId == hostId &&
          row.seekerId == seekerId &&
          row.listingId == listingId,
    );
    decisions.add(
      BoardDecision(
        hostId: hostId,
        seekerId: seekerId,
        listingId: listingId,
        decision: decision,
      ),
    );
    if (decision == 'accepted') {
      likePerson(actorId: hostId, otherUserId: seekerId);
    }
  }

  void send({
    required String matchId,
    required String senderId,
    required String body,
  }) {
    final match = matches.where((row) => row.matchId == matchId);
    if (match.isEmpty) {
      throw StateError('no match');
    }
    messages.add(
      BoardMessage(matchId: matchId, senderId: senderId, body: body),
    );
  }

  List<BoardLike> incomingLikes(String userId) {
    return [
      for (final like in likes)
        if (like.targetUserId == userId) like,
    ];
  }

  Set<String> savedBy(String userId) {
    return {
      for (final save in saves)
        if (save.actorId == userId) save.listingId,
    };
  }

  List<BoardDecision> outcomesFor(String seekerId) {
    return [
      for (final row in decisions)
        if (row.seekerId == seekerId) row,
    ];
  }

  List<BoardMessage> thread(String matchId) {
    return [
      for (final message in messages)
        if (message.matchId == matchId) message,
    ];
  }

  BoardMatch? matchBetween(String a, String b) {
    for (final match in matches) {
      if (match.has(a) && match.has(b)) {
        return match;
      }
    }
    return null;
  }

  void _openMatchIfMutual(String a, String b) {
    final aLikesB = likes.any(
      (like) => like.actorId == a && like.targetUserId == b,
    );
    final bLikesA = likes.any(
      (like) => like.actorId == b && like.targetUserId == a,
    );
    if (!aLikesB || !bLikesA || matchBetween(a, b) != null) {
      return;
    }
    matches.add(
      BoardMatch(matchId: 'match-$a-$b', participantA: a, participantB: b),
    );
  }
}

class BoardLike {
  const BoardLike({
    required this.actorId,
    required this.targetUserId,
    required this.targetType,
    required this.targetId,
  });

  final String actorId;
  final String targetUserId;
  final String targetType;
  final String targetId;
}

class BoardSave {
  const BoardSave({required this.actorId, required this.listingId});

  final String actorId;
  final String listingId;
}

class BoardDecision {
  const BoardDecision({
    required this.hostId,
    required this.seekerId,
    required this.listingId,
    required this.decision,
  });

  final String hostId;
  final String seekerId;
  final String listingId;
  final String decision;
}

class BoardMessage {
  const BoardMessage({
    required this.matchId,
    required this.senderId,
    required this.body,
  });

  final String matchId;
  final String senderId;
  final String body;
}

class BoardMatch {
  const BoardMatch({
    required this.matchId,
    required this.participantA,
    required this.participantB,
  });

  final String matchId;
  final String participantA;
  final String participantB;

  bool has(String userId) => userId == participantA || userId == participantB;
}
