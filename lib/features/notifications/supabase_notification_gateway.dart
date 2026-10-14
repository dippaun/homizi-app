import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/notification_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Selects the signed-in person's rows and updates `read_at` only.
class SupabaseNotificationGateway implements NotificationGateway {
  SupabaseNotificationGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<InboxSnapshot> load({List<String> demoMatchIds = const []}) async {
    return InboxSnapshot(items: await _fetch());
  }

  @override
  Future<InboxSnapshot> markRead(String id) async {
    await _mark(id);
    return InboxSnapshot(items: await _fetch(), note: InboxCopy.serverMarked);
  }

  @override
  Future<InboxSnapshot> markAllRead() async {
    final current = await _fetch();
    for (final item in current) {
      if (item.unread) {
        await _mark(item.id);
      }
    }
    return InboxSnapshot(items: await _fetch(), note: InboxCopy.serverMarked);
  }

  Future<void> _mark(String id) async {
    _requireUser();
    final patch = notificationReadPatch(DateTime.now().toUtc());
    if (patch.keys.toSet().difference({'read_at'}).isNotEmpty) {
      throw const InboxFailure('A notification update can only set read_at.');
    }
    await _guard(
      () => _client.from('notifications').update(patch).eq('id', id),
    );
  }

  Future<List<InboxNotice>> _fetch() async {
    final user = _requireUser();
    final rows = await _guard(
      () => _client
          .from('notifications')
          .select('id, type, payload_minimal, read_at, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false),
    );
    return [
      for (final raw in rows) noticeFromRow(_map(raw)),
    ].whereType<InboxNotice>().toList();
  }

  User _requireUser() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const InboxFailure('Sign in before opening notifications.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on InboxFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw InboxFailure(_safe(error.message));
    } on AuthException catch (error) {
      throw InboxFailure(_safe(error.message));
    } catch (error) {
      final offline = offlineFailureMessage(error);
      if (offline != null) {
        throw InboxFailure(offline);
      }
      rethrow;
    }
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw const InboxFailure('The notification list was not readable.');
}

String _safe(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty || trimmed.length > 180 || containsContact(trimmed)) {
    return 'The notification request failed. Contact details stay on the server.';
  }
  return trimmed;
}

bool containsContact(String value) {
  final lower = value.toLowerCase();
  return lower.contains('@') ||
      RegExp(
        r'[0-9]{10,}',
      ).hasMatch(lower.replaceAll(RegExp(r'[\s\-.()]'), ''));
}
