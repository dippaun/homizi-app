import 'package:homizi/features/analytics/analytics_gateway.dart';
import 'package:homizi/features/analytics/domain/analytics_event.dart';
import 'package:homizi/features/safety/domain/safety_rules.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inserts one row for the signed-in person. A failure is ignored so a
/// count never blocks chat, discovery, or sign-in.
class SupabaseAnalyticsGateway implements AnalyticsGateway {
  SupabaseAnalyticsGateway(this._client, {required this.optedOut});

  final SupabaseClient _client;
  final bool Function() optedOut;

  @override
  Future<void> log(
    String name, {
    Map<String, String> properties = const {},
  }) async {
    final userId = _client.auth.currentUser?.id;
    final write = analyticsWrite(
      optedOut: optedOut(),
      userId: userId,
      name: name,
      properties: properties,
    );
    if (write == null || !safetySubjectIsUuid(userId ?? '')) {
      return;
    }
    try {
      await _client.from('analytics_events').insert(write);
    } catch (_) {
      // The screen stays usable when the events table is unreachable.
    }
  }
}
