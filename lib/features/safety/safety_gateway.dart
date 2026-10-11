class SafetyFailure implements Exception {
  const SafetyFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class SafetyResult {
  const SafetyResult({required this.message, required this.storedOnServer});

  final String message;
  final bool storedOnServer;
}

/// Files a report and, when an account id is present, a block.
/// The client never sets report status and never sends a phone or email.
abstract interface class SafetyGateway {
  Future<SafetyResult> submit({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
    String? blockedUserId,
    bool alsoBlock = false,
  });
}
