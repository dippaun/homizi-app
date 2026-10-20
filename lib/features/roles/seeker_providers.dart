import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/roles/demo_seekers.dart';
import 'package:homizi/features/roles/seeker_match.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final seekerMatchGatewayProvider = Provider<SeekerMatchGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  if (!config.connectsToSupabase || forceDemo) {
    return _DemoSeekerMatchGateway();
  }
  return SupabaseSeekerMatchGateway(
    Supabase.instance.client,
    demoFallback: config.demoSkipLogin,
  );
});

class _DemoSeekerMatchGateway implements SeekerMatchGateway {
  @override
  Future<SeekerMatchPage> load() async => demoSeekerPage();
}

class SupabaseSeekerMatchGateway implements SeekerMatchGateway {
  const SupabaseSeekerMatchGateway(this._client, {this.demoFallback = false});

  final SupabaseClient _client;
  final bool demoFallback;

  @override
  Future<SeekerMatchPage> load() async {
    try {
      final raw = await _client.rpc<dynamic>('seekers_for_my_listings');
      final rows = raw is List ? raw : const <dynamic>[];
      final seekers = <SeekerMatch>[
        for (final row in rows)
          if (row is Map) _fromMap(Map<String, dynamic>.from(row)),
      ]..sort((a, b) => b.matchPercent.compareTo(a.matchPercent));
      if (seekers.isEmpty && demoFallback) {
        return demoSeekerPage();
      }
      return SeekerMatchPage(
        seekers: seekers,
        basis: 'Scores use your listings. Phone numbers stay hidden.',
      );
    } catch (_) {
      if (demoFallback) {
        return demoSeekerPage();
      }
      rethrow;
    }
  }

  SeekerMatch _fromMap(Map<String, dynamic> row) {
    final localities = row['localities'];
    return SeekerMatch(
      requirementId: row['requirement_id']?.toString() ?? '',
      displayName: _text(row['display_name'], fallback: 'Seeker'),
      city: _text(row['city']),
      localities: localities is List
          ? [for (final item in localities) item.toString()]
          : const [],
      budgetMinInr: _int(row['budget_min_inr']),
      budgetMaxInr: _int(row['budget_max_inr']),
      roomType: _joined(row['room_type']),
      seekerKind: _text(row['seeker_kind'], fallback: 'tenant'),
      aboutMe: _text(row['about_me']),
      profession: _joined(row['profession']),
      matchPercent: _int(row['match_percent']),
    );
  }

  String _text(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  String _joined(Object? value) {
    if (value is List) {
      return [
        for (final item in value)
          if (item.toString().trim().isNotEmpty) item.toString().trim(),
      ].join(', ');
    }
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  int _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }
}
