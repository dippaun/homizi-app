import 'package:homizi/features/notifications/domain/inbox_notice.dart';

class InboxFailure implements Exception {
  const InboxFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the signed-in person's notifications and marks them read.
/// The client never inserts a notification and never writes the payload.
abstract interface class NotificationGateway {
  Future<InboxSnapshot> load({List<String> demoMatchIds = const []});

  Future<InboxSnapshot> markRead(String id);

  Future<InboxSnapshot> markAllRead();
}
