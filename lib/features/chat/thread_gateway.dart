import 'package:homizi/features/chat/domain/thread_state.dart';

class ThreadFailure implements Exception {
  const ThreadFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Chat and visit requests for one match.
/// Contact fields are never part of the snapshot.
abstract interface class ThreadGateway {
  Future<ThreadSnapshot> load(String matchId);

  Future<ThreadSnapshot> send(String matchId, String body);

  Future<ThreadSnapshot> requestVisit(String matchId, List<DateTime> slots);

  Future<ThreadSnapshot> proposeVisitTime(String visitId, List<DateTime> slots);

  Future<ThreadSnapshot> respondVisit(String visitId, String status);

  /// Inserts from the server. Demo mode is an empty stream so the device
  /// thread stays local. Callers still have to hide contact text.
  Stream<ChatMessage> watchMessages(String matchId);

  /// Conversations the signed-in person can open. Demo mode returns sample threads.
  Future<List<ConversationPreview>> listConversations();

  /// Clears the unread count for [matchId] on this device.
  /// A later reply from the other person is what draws the second tick.
  Future<void> markRead(String matchId);

  /// Fires when a thread's last message or unread count changes.
  Stream<void> watchInbox();
}
