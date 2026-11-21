import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Best-effort writes for a real signed-in account.
///
/// A missing session, a demo id, or a table that is not applied yet leaves
/// the device copy in place. Nothing here sends a non-uuid to Postgres.
abstract final class LiveAccountSync {
  static Future<String?> _userId() async {
    try {
      final id = Supabase.instance.client.auth.currentUser?.id ?? '';
      if (!isUuid(id)) {
        return null;
      }
      return id;
    } on Object {
      return null;
    }
  }

  /// Full roommate brief. Mapped columns update even before `brief` exists.
  static Future<void> roommateBrief(Map<String, dynamic> json) async {
    final userId = await _userId();
    if (userId == null) {
      return;
    }
    final city = json['city'] is String ? (json['city'] as String).trim() : '';
    final places = _places(json['localities']);
    final food = json['food'] == 'jain' ? 'veg' : json['food'];
    final row = <String, dynamic>{
      'user_id': userId,
      'city': city,
      'localities': places,
      'discoverable': json['profilePosted'] == true,
      'open_to_flatmates': json['profilePosted'] == true,
      'brief': json,
    };
    void put(String key, Object? value) {
      if (value != null) {
        row[key] = value;
      }
    }

    put('budget_min_inr', _money(json['budgetMin']));
    put('budget_max_inr', _money(json['budgetMax']));
    put('food', _enum(food, const ['veg', 'eggetarian', 'non_veg', 'any']));
    put(
      'smoking',
      _enum(json['smoking'], const ['never', 'sometimes', 'regularly']),
    );
    put('pets', _enum(json['pets'], const ['none', 'has', 'ok']));
    put('sleep', _enum(json['sleep'], const ['early', 'flexible', 'night']));
    put('cleanliness', _clean(json['cleanliness']));
    put('guests', _enum(json['guests'], const ['rare', 'sometimes', 'often']));
    put('wfh', _enum(json['schedule'], const ['office', 'hybrid', 'home']));
    final languages = _places(json['languages']);
    if (languages.isNotEmpty) {
      row['languages'] = languages;
    }
    put(
      'gender',
      _enum(json['ownGender'], const [
        'woman',
        'man',
        'nonbinary',
        'undisclosed',
      ]),
    );
    put('age', _age(json['ownAge']));
    put(
      'gender_preference',
      _enum(_wantText(json, 'gender'), const ['any', 'women', 'men', 'same']),
    );
    put('move_in_date', _moveDate(json));
    try {
      await Supabase.instance.client.from('roommate_profiles').upsert(row);
    } on Object {
      row.remove('brief');
      try {
        await Supabase.instance.client.from('roommate_profiles').upsert(row);
      } on Object {
        // Device copy remains the fallback.
      }
    }
  }

  static Future<Map<String, dynamic>?> loadRoommateBrief() async {
    final userId = await _userId();
    if (userId == null) {
      return null;
    }
    try {
      final row = await Supabase.instance.client
          .from('roommate_profiles')
          .select('brief')
          .eq('user_id', userId)
          .maybeSingle();
      final brief = row?['brief'];
      if (brief is Map<String, dynamic>) {
        return brief;
      }
      if (brief is Map) {
        return brief.map((key, value) => MapEntry('$key', value));
      }
    } on Object {
      return null;
    }
    return null;
  }

  /// Tenant home form. Localities and occupancy use existing columns.
  /// The full form is `intake` after the persistence migration.
  static Future<void> tenantIntake(Map<String, dynamic> json) async {
    final userId = await _userId();
    if (userId == null) {
      return;
    }
    final rooms = _money(json['rooms']) ?? 1;
    final occupancy = rooms < 1 ? 1 : (rooms > 20 ? 20 : rooms);
    final places = _places(json['address']);
    final base = <String, dynamic>{
      'user_id': userId,
      'localities': places,
      'occupancy': occupancy,
    };
    await _upsertPreferences(userId, base, extra: {'intake': json});
  }

  static Future<void> browseLocalities(List<String> localities) async {
    final userId = await _userId();
    if (userId == null) {
      return;
    }
    final places = [
      for (final name in localities)
        if (name.trim().isNotEmpty) name.trim(),
    ];
    if (places.isEmpty) {
      return;
    }
    await _upsertPreferences(userId, {'user_id': userId, 'localities': places});
  }

  /// Host shortlist and dismiss. `save` and `pass` already exist on interests.
  static Future<void> seekerStance({
    required String targetId,
    required String action,
  }) async {
    if (!isUuid(targetId)) {
      return;
    }
    if (action != 'save' && action != 'pass' && action != 'like') {
      return;
    }
    final userId = await _userId();
    if (userId == null || userId == targetId) {
      return;
    }
    try {
      await Supabase.instance.client.rpc<dynamic>(
        'create_interest',
        params: interestParams(
          targetId: targetId,
          action: action,
          targetType: 'user',
        ),
      );
    } on Object {
      // The deck on this device still records the tap.
    }
  }

  /// In-app "more" note. Topic must be one the support table allows.
  static Future<void> supportNote({
    required String topic,
    required String message,
  }) async {
    const allowed = {'renting', 'flatmates', 'safety', 'payments', 'other'};
    final cleanTopic = allowed.contains(topic) ? topic : 'other';
    final text = message.trim();
    if (text.length < 10 || text.length > 1000) {
      return;
    }
    if (text.contains('@') || RegExp(r'[0-9]{10}').hasMatch(text)) {
      return;
    }
    final userId = await _userId();
    if (userId == null) {
      return;
    }
    try {
      await Supabase.instance.client.from('support_tickets').insert({
        'user_id': userId,
        'topic': cleanTopic,
        'message': text,
      });
    } on Object {
      // Local list remains.
    }
  }

  static Future<void> _upsertPreferences(
    String userId,
    Map<String, dynamic> row, {
    Map<String, dynamic> extra = const {},
  }) async {
    try {
      await Supabase.instance.client.from('tenant_preferences').upsert({
        ...row,
        ...extra,
      });
    } on Object {
      if (extra.isEmpty) {
        return;
      }
      try {
        await Supabase.instance.client.from('tenant_preferences').upsert(row);
      } on Object {
        // Device copy remains.
      }
    }
  }

  static List<String> _places(Object? raw) {
    if (raw is List) {
      return [
        for (final item in raw)
          if ('$item'.trim().isNotEmpty) '$item'.trim(),
      ];
    }
    if (raw is String && raw.trim().isNotEmpty) {
      return [raw.trim()];
    }
    return const [];
  }

  static int? _money(Object? raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return null;
  }

  static String? _enum(Object? raw, List<String> allowed) {
    if (raw is! String) {
      return null;
    }
    final value = raw.trim();
    return allowed.contains(value) ? value : null;
  }

  static int? _clean(Object? raw) {
    final value = _money(raw);
    if (value == null || value < 1 || value > 5) {
      return null;
    }
    return value;
  }

  static int? _age(Object? raw) {
    final value = _money(raw);
    if (value == null || value < 18 || value > 99) {
      return null;
    }
    return value;
  }

  static String? _wantText(Map<String, dynamic> json, String key) {
    final want = json['want'];
    if (want is Map && want[key] is String) {
      return want[key] as String;
    }
    final own = json[key];
    return own is String ? own : null;
  }

  static String? _moveDate(Map<String, dynamic> json) {
    final year = _money(json['moveYear']);
    final month = _money(json['moveMonth']);
    final day = _money(json['moveDay']);
    if (year == null || month == null || day == null) {
      return null;
    }
    if (month < 1 || month > 12 || day < 1 || day > 31) {
      return null;
    }
    final mm = month.toString().padLeft(2, '0');
    final dd = day.toString().padLeft(2, '0');
    return '$year-$mm-$dd';
  }
}
