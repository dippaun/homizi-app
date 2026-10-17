import 'package:homizi/features/agreements/agreement_gateway.dart';
import 'package:homizi/features/agreements/domain/agreement_rules.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAgreementGateway implements AgreementGateway {
  SupabaseAgreementGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<AgreementRecord>> listMine() async {
    final rows = await _client
        .from('agreements')
        .select(
          'id, title, status, provider, provider_reference, stamp_amount_inr, source_draft_id, draft_body',
        )
        .order('created_at', ascending: false);
    return [
      for (final raw in rows) _record(Map<String, dynamic>.from(raw as Map)),
    ];
  }

  @override
  Future<AgreementRecord> createDraft({
    required String matchId,
    required String title,
    required String body,
    required String tenantName,
    required String ownerName,
    int? stampAmountInr,
    String? sourceDraftId,
  }) async {
    final raw = await _client.rpc<dynamic>(
      'create_agreement',
      params: {
        'p_match_id': matchId,
        'p_title': title,
        'p_draft_body': body,
        'p_stamp_amount_inr': stampAmountInr,
        'p_source_draft_id': sourceDraftId,
      },
    );
    return _fromRpc(raw);
  }

  @override
  Future<AgreementRecord> sendForSignature(String id) async {
    try {
      final response = await _client.functions.invoke(
        'create-esign',
        body: {'agreement_id': id},
      );
      final data = response.data;
      if (data is Map && data['agreement'] is Map) {
        return _record(Map<String, dynamic>.from(data['agreement'] as Map));
      }
    } catch (_) {
      // Demo provider path below when the function is not deployed.
    }
    final raw = await _client.rpc<dynamic>(
      'send_agreement',
      params: {'p_agreement_id': id},
    );
    return _fromRpc(raw);
  }

  @override
  Future<AgreementRecord> demoSign(String id, {required String role}) async {
    final raw = await _client.rpc<dynamic>(
      'demo_sign_agreement',
      params: {'p_agreement_id': id, 'p_role': role},
    );
    return _fromRpc(raw);
  }

  AgreementRecord _fromRpc(Object? raw) {
    if (raw is! Map) {
      throw const AgreementFailure('The agreement service did not answer.');
    }
    final body = Map<String, dynamic>.from(raw);
    if (body['ok'] != true || body['agreement'] is! Map) {
      throw AgreementFailure(_message(body['error']));
    }
    return _record(Map<String, dynamic>.from(body['agreement'] as Map));
  }

  AgreementRecord _record(Map<String, dynamic> row) {
    final stamp = row['stamp_amount_inr'];
    return AgreementRecord(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? 'Agreement',
      status: agreementStatusFromWire(row['status'] as String?),
      provider: row['provider'] as String? ?? 'demo',
      tenantName: 'Tenant',
      ownerName: 'Owner',
      providerReference: row['provider_reference'] as String?,
      stampAmountInr: stamp is num ? stamp.toInt() : null,
      sourceDraftId: row['source_draft_id'] as String?,
      body: row['draft_body'] as String? ?? '',
    );
  }

  String _message(Object? code) {
    return switch (code) {
      'not_participant' => 'Use an agreement on your own match.',
      'provider' => 'This provider updates the status from its webhook.',
      'status' => 'That status change is not available.',
      _ => 'The agreement was not updated.',
    };
  }
}
