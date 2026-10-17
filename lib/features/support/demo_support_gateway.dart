import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/support/domain/faq_catalog.dart';
import 'package:homizi/features/support/support_gateway.dart';

class DemoSupportGateway implements SupportGateway {
  final List<SupportTicket> _tickets = [];

  @override
  Future<List<SupportTicket>> loadMine() async => [..._tickets];

  @override
  Future<SupportTicket> submit({
    required String topic,
    required String message,
  }) async {
    if (!supportTopics.contains(topic)) {
      throw const SupportFailure('Choose a topic.');
    }
    final error = supportMessageError(message);
    if (error != null) {
      throw SupportFailure(error);
    }
    final ticket = SupportTicket(
      id: newLocalId(),
      topic: topic,
      message: message.trim(),
      createdAt: DateTime.now().toUtc(),
    );
    _tickets.insert(0, ticket);
    return ticket;
  }
}
