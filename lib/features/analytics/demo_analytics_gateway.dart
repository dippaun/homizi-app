import 'package:homizi/features/analytics/analytics_gateway.dart';
import 'package:homizi/features/analytics/domain/analytics_event.dart';

/// Keeps accepted events in memory. Demo mode does not send them anywhere.
class DemoAnalyticsGateway implements AnalyticsGateway {
  DemoAnalyticsGateway({required this.optedOut, this.userId = 'demo-self'});

  final bool Function() optedOut;
  final String userId;
  final List<Map<String, Object?>> events = [];

  @override
  Future<void> log(
    String name, {
    Map<String, String> properties = const {},
  }) async {
    final write = analyticsWrite(
      optedOut: optedOut(),
      userId: userId,
      name: name,
      properties: properties,
    );
    if (write == null) {
      return;
    }
    events.add(write);
  }
}
