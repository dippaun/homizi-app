class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.topic,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String topic;
  final String message;
  final DateTime createdAt;
}

class SupportFailure implements Exception {
  const SupportFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

const supportTopics = <String>['renting', 'flatmates', 'safety', 'payments'];

abstract interface class SupportGateway {
  Future<SupportTicket> submit({
    required String topic,
    required String message,
  });

  Future<List<SupportTicket>> loadMine();
}
