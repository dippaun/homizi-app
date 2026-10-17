import 'package:homizi/features/push/domain/push_rules.dart';

abstract interface class PushGateway {
  bool get configured;

  /// Registers for push when [configured] is true. Otherwise it returns.
  Future<void> start();

  Future<void> setEnabled(bool enabled);
}

class DeviceTokenStore {
  const DeviceTokenStore({required this.save, required this.remove});

  final Future<void> Function(String token, String platform) save;
  final Future<void> Function(String token) remove;
}

/// Push stays off. The in-app inbox is unchanged.
class InertPushGateway implements PushGateway {
  bool enabled = true;

  @override
  bool get configured => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
  }
}

/// Used by tests and by the inert path. Confirms the category map is the
/// same one the edge function documents.
bool shouldDeliverPush(String type) => pushCategoryForType(type) != null;
