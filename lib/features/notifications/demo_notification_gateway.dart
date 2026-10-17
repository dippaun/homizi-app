import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/domain/notice_category.dart';
import 'package:homizi/features/notifications/domain/notification_preferences.dart';
import 'package:homizi/features/notifications/notification_gateway.dart';

/// Device-only inbox used when the project URL or public key is empty.
/// Stored rows still pass through the same payload filter as the server.
class DemoNotificationGateway implements NotificationGateway {
  final List<InboxNotice> _items = [];
  NotificationPreferences _preferences = NotificationPreferences.standard;

  void seed(InboxNotice notice) {
    _items.add(_kept(notice));
  }

  /// Parses a row the way the server client does, then drops contact fields.
  void seedRow(Map<String, dynamic> row) {
    final notice = noticeFromRow(row);
    if (notice != null) {
      _items.add(_kept(notice));
    }
  }

  @override
  Future<InboxSnapshot> load({List<String> demoMatchIds = const []}) async {
    for (final matchId in demoMatchIds) {
      final payload = sanitizeNoticePayload({'match_id': matchId});
      final safeMatchId = payload['match_id'];
      if (safeMatchId == null) {
        continue;
      }
      final exists = _items.any(
        (item) => item.type == 'match' && item.matchId == safeMatchId,
      );
      if (exists || !_preferences.enabled(NoticeCategory.matches)) {
        continue;
      }
      _items.add(
        InboxNotice(
          id: newLocalId(),
          type: 'match',
          matchId: safeMatchId,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    return _snapshot(null);
  }

  @override
  Future<InboxSnapshot> markRead(String id) async {
    _mark(id);
    return _snapshot(InboxCopy.demoMarked);
  }

  @override
  Future<InboxSnapshot> markAllRead() async {
    for (final item in _items) {
      if (item.unread) {
        _mark(item.id);
      }
    }
    return _snapshot(InboxCopy.demoMarked);
  }

  @override
  Future<InboxSnapshot> dismiss(String id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const InboxFailure('That notification is not on this device.');
    }
    _items.removeAt(index);
    return _snapshot(InboxCopy.demoDismissed);
  }

  @override
  Future<NotificationPreferences> loadPreferences() async => _preferences;

  @override
  Future<NotificationPreferences> savePreferences(
    NotificationPreferences prefs,
  ) async {
    _preferences = prefs;
    return _preferences;
  }

  void _mark(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const InboxFailure('That notification is not on this device.');
    }
    final current = _items[index];
    _items[index] = InboxNotice(
      id: current.id,
      type: current.type,
      matchId: current.matchId,
      propertyId: current.propertyId,
      createdAt: current.createdAt,
      readAt: current.readAt ?? DateTime.now().toUtc(),
    );
  }

  InboxNotice _kept(InboxNotice item) {
    final matchId = item.matchId == null
        ? null
        : sanitizeNoticePayload({'match_id': item.matchId})['match_id'];
    final propertyId = item.propertyId == null
        ? null
        : sanitizeNoticePayload({
            'property_id': item.propertyId,
          })['property_id'];
    return InboxNotice(
      id: item.id,
      type: item.type,
      matchId: matchId,
      propertyId: propertyId,
      createdAt: item.createdAt,
      readAt: item.readAt,
    );
  }

  InboxSnapshot _snapshot(String? note) {
    final items = [..._items]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return InboxSnapshot(items: items, note: note);
  }
}
