import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/broker/broker_profile.dart';
import 'package:homizi/features/demo/demo_copy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final brokerGatewayProvider = Provider<BrokerGateway>((ref) {
  final config = ref.watch(appConfigProvider);
  final forceDemo = ref.watch(forceDemoModeProvider);
  final local = _DemoBrokerGateway(
    seed: config.demoSkipLogin ? demoBrokerProfile : null,
  );
  if (!config.connectsToSupabase || forceDemo) {
    return local;
  }
  final remote = SupabaseBrokerGateway(Supabase.instance.client);
  if (!config.demoSkipLogin) {
    return remote;
  }
  return _BrokerFallback(remote, local);
});

class _BrokerFallback implements BrokerGateway {
  _BrokerFallback(this._remote, this._local);

  final BrokerGateway _remote;
  final BrokerGateway _local;

  @override
  Future<BrokerProfileDraft?> load() async {
    try {
      final row = await _remote.load();
      if (row != null && row.fullName.trim().isNotEmpty) {
        return row;
      }
    } catch (_) {
      // A missing server profile still uses the demo desk profile.
    }
    return _local.load();
  }

  @override
  Future<void> save(BrokerProfileDraft draft) async {
    try {
      await _remote.save(draft);
    } catch (error) {
      if (isDemoSignInCopy(error.toString())) {
        await _local.save(draft);
        return;
      }
      rethrow;
    }
  }
}

const demoBrokerProfile = BrokerProfileDraft(
  fullName: 'Meenal Deshpande',
  agencyName: 'Deshpande Realty',
  reraNumber: 'PRM/KA/RERA/1251/446/AG/171018/000441',
  cities: ['Bengaluru'],
  localities: ['Koramangala'],
  phone: '9876543210',
  yearsExperience: 6,
);

class _DemoBrokerGateway implements BrokerGateway {
  _DemoBrokerGateway({BrokerProfileDraft? seed}) : _draft = seed;

  BrokerProfileDraft? _draft;

  @override
  Future<BrokerProfileDraft?> load() async => _draft;

  @override
  Future<void> save(BrokerProfileDraft draft) async {
    final issues = draft.errors();
    if (issues.isNotEmpty) {
      throw BrokerFailure(issues.first);
    }
    _draft = draft;
  }
}

class BrokerFailure implements Exception {
  const BrokerFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class SupabaseBrokerGateway implements BrokerGateway {
  const SupabaseBrokerGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<BrokerProfileDraft?> load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return null;
    }
    final rows = await _client
        .from('broker_profiles')
        .select(
          'full_name, agency_name, rera_number, cities, localities, phone, years_experience',
        )
        .eq('user_id', user.id)
        .limit(1);
    if (rows.isEmpty) {
      return null;
    }
    final row = Map<String, dynamic>.from(rows.first as Map);
    return BrokerProfileDraft(
      fullName: _text(row['full_name']),
      agencyName: _text(row['agency_name']),
      reraNumber: _text(row['rera_number']),
      cities: _list(row['cities']),
      localities: _list(row['localities']),
      phone: _text(row['phone']),
      yearsExperience: row['years_experience'] is int
          ? row['years_experience'] as int
          : 0,
    );
  }

  @override
  Future<void> save(BrokerProfileDraft draft) async {
    final issues = draft.errors();
    if (issues.isNotEmpty) {
      throw BrokerFailure(issues.first);
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const BrokerFailure('Sign in before saving a broker profile.');
    }
    final phone = draft.phoneE164!;
    await _client.from('broker_profiles').upsert({
      'user_id': user.id,
      'full_name': draft.fullName.trim(),
      'agency_name': draft.agencyName.trim(),
      'rera_number': draft.reraNumber.trim().isEmpty
          ? null
          : draft.reraNumber.trim(),
      'cities': draft.cities,
      'localities': [
        for (final item in draft.localities)
          if (item.trim().isNotEmpty) item.trim(),
      ],
      'phone': phone,
      'years_experience': draft.yearsExperience,
    });
    await _client.from('private_contacts').upsert({
      'user_id': user.id,
      'phone': phone,
    });
    await _client
        .from('profiles')
        .update({
          'display_name': draft.fullName.trim(),
          'primary_role': 'broker',
        })
        .eq('user_id', user.id);
    await _client.from('host_profiles').upsert({
      'user_id': user.id,
      'host_category': 'broker',
      'company_name': draft.agencyName.trim(),
    });
  }

  String _text(Object? value) => value is String ? value : '';

  List<String> _list(Object? value) {
    if (value is! List) {
      return const [];
    }
    return [for (final item in value) item.toString()];
  }
}
