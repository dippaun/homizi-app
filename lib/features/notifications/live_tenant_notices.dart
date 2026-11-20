import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A tenant alert built from listings, roommates, likes, and messages.
class TenantLiveNotice {
  const TenantLiveNotice({
    required this.id,
    required this.title,
    required this.detail,
    required this.createdAt,
    this.demo = false,
  });

  final String id;
  final String title;
  final String detail;
  final DateTime createdAt;
  final bool demo;
}

/// Sample alerts so the inbox can be tried before live rows exist.
List<TenantLiveNotice> demoTenantNotices() {
  final now = DateTime.now().toUtc();
  return [
    TenantLiveNotice(
      id: 'demo-live-posting',
      title: 'New posting in your area',
      detail: 'A home was just listed in a locality you prefer.',
      createdAt: now.subtract(const Duration(minutes: 12)),
      demo: true,
    ),
    TenantLiveNotice(
      id: 'demo-live-roommate',
      title: 'New roommate with a good match',
      detail: 'A roommate profile lines up with your budget and lifestyle.',
      createdAt: now.subtract(const Duration(hours: 2)),
      demo: true,
    ),
    TenantLiveNotice(
      id: 'demo-live-interest',
      title: 'New interest',
      detail: 'Someone liked a home you saved.',
      createdAt: now.subtract(const Duration(hours: 5)),
      demo: true,
    ),
    TenantLiveNotice(
      id: 'demo-live-message',
      title: 'New message',
      detail: 'You have a new message on a match.',
      createdAt: now.subtract(const Duration(days: 1)),
      demo: true,
    ),
  ];
}

/// Reads live rows the signed-in tenant can already see. No new table.
Future<List<TenantLiveNotice>> loadTenantLiveNotices(WidgetRef ref) async {
  final config = ref.read(appConfigProvider);
  final demo = !config.connectsToSupabase || ref.read(forceDemoModeProvider);
  if (demo) {
    return demoTenantNotices();
  }
  final areas = await _areas(ref);
  final live = <TenantLiveNotice>[];
  try {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      return demoTenantNotices();
    }
    live.addAll(await _postings(client, areas));
    live.addAll(await _roommates(client, user.id));
    live.addAll(await _likes(client, user.id));
    live.addAll(await _messages(client, user.id));
  } on Object {
    return demoTenantNotices();
  }
  live.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  if (live.isEmpty) {
    return demoTenantNotices();
  }
  return live;
}

Future<List<String>> _areas(WidgetRef ref) async {
  try {
    final profile = await ref.read(accountGatewayProvider).loadTenantProfile();
    return [
      for (final place in [
        profile.preferences.city,
        ...profile.preferences.localities,
      ])
        if (place.trim().isNotEmpty) place.trim().toLowerCase(),
    ];
  } on Object {
    return const [];
  }
}

Future<List<TenantLiveNotice>> _postings(
  SupabaseClient client,
  List<String> areas,
) async {
  final raw = await client
      .from('properties')
      .select('id, title, locality, city, status, created_at')
      .eq('status', 'published')
      .order('created_at', ascending: false)
      .limit(24);
  final notices = <TenantLiveNotice>[];
  for (final row in _rows(raw)) {
    final locality = _text(row['locality']);
    final city = _text(row['city']);
    final haystack = '${locality.toLowerCase()} ${city.toLowerCase()}';
    final preferred =
        areas.isEmpty || areas.any((area) => haystack.contains(area));
    if (!preferred) {
      continue;
    }
    final id = _text(row['id']);
    if (id.isEmpty) {
      continue;
    }
    final title = _text(row['title']);
    final place = [
      if (locality.isNotEmpty) locality,
      if (city.isNotEmpty) city,
    ].join(', ');
    notices.add(
      TenantLiveNotice(
        id: 'posting-$id',
        title: 'New posting in your area',
        detail: place.isEmpty ? title : '$title · $place',
        createdAt: _time(row['created_at']),
      ),
    );
  }
  return notices.take(8).toList();
}

Future<List<TenantLiveNotice>> _roommates(
  SupabaseClient client,
  String userId,
) async {
  final raw = await client
      .from('profiles')
      .select('user_id, display_name, occupation, primary_role')
      .eq('primary_role', 'roommate')
      .limit(12);
  final notices = <TenantLiveNotice>[];
  for (final row in _rows(raw)) {
    final id = _text(row['user_id']);
    if (id.isEmpty || id == userId) {
      continue;
    }
    final name = _text(row['display_name']);
    final job = _text(row['occupation']);
    notices.add(
      TenantLiveNotice(
        id: 'roommate-$id',
        title: 'New roommate with a good match',
        detail: [
          if (name.isNotEmpty) name,
          if (job.isNotEmpty) job,
          if (name.isEmpty && job.isEmpty) 'A roommate profile is new',
        ].join(' · '),
        createdAt: DateTime.now().toUtc(),
      ),
    );
  }
  return notices.take(6).toList();
}

Future<List<TenantLiveNotice>> _likes(
  SupabaseClient client,
  String userId,
) async {
  final raw = await client
      .from('interests')
      .select('id, actor_user_id, action, created_at')
      .eq('action', 'like')
      .order('created_at', ascending: false)
      .limit(16);
  final notices = <TenantLiveNotice>[];
  for (final row in _rows(raw)) {
    final actor = _text(row['actor_user_id']);
    if (actor.isEmpty || actor == userId) {
      continue;
    }
    final id = _text(row['id']);
    if (id.isEmpty) {
      continue;
    }
    notices.add(
      TenantLiveNotice(
        id: 'like-$id',
        title: 'New interest',
        detail: 'Someone liked a home.',
        createdAt: _time(row['created_at']),
      ),
    );
  }
  return notices.take(6).toList();
}

Future<List<TenantLiveNotice>> _messages(
  SupabaseClient client,
  String userId,
) async {
  final raw = await client
      .from('messages')
      .select('id, sender_id, created_at')
      .order('created_at', ascending: false)
      .limit(16);
  final notices = <TenantLiveNotice>[];
  for (final row in _rows(raw)) {
    final sender = _text(row['sender_id']);
    if (sender.isEmpty || sender == userId) {
      continue;
    }
    final id = _text(row['id']);
    if (id.isEmpty) {
      continue;
    }
    notices.add(
      TenantLiveNotice(
        id: 'message-$id',
        title: 'New message',
        detail: 'You have a new message.',
        createdAt: _time(row['created_at']),
      ),
    );
  }
  return notices.take(6).toList();
}

List<Map<String, Object?>> _rows(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}

String _text(Object? value) => value is String ? value.trim() : '';

DateTime _time(Object? value) {
  if (value is String) {
    return DateTime.tryParse(value)?.toUtc() ?? DateTime.now().toUtc();
  }
  return DateTime.now().toUtc();
}
