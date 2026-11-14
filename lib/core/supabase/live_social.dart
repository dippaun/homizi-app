import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Tables a second signed-in person should see without refreshing.
const liveSocialTables = <String>[
  'properties',
  'interests',
  'matches',
  'messages',
];

/// Emits when one of [liveSocialTables] changes.
///
/// Uses the Supabase row stream, which listens on a realtime channel. A table
/// that is not in the publication yet, or a project that has not been migrated,
/// produces no events and does not surface an error to the screen.
Stream<void> openLiveSocialChanges(SupabaseClient client) {
  final controller = StreamController<void>.broadcast();
  final subscriptions = <StreamSubscription<List<Map<String, dynamic>>>>[];

  controller.onListen = () {
    for (final table in liveSocialTables) {
      try {
        final subscription = client
            .from(table)
            .stream(primaryKey: ['id'])
            .listen(
              (_) {
                if (!controller.isClosed) {
                  controller.add(null);
                }
              },
              onError: (_) {},
              cancelOnError: false,
            );
        subscriptions.add(subscription);
      } on Object {
        // The stream is unavailable until the table is in the publication.
      }
    }
  };
  controller.onCancel = () async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    subscriptions.clear();
  };
  return controller.stream;
}
