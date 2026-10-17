import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseKycGateway implements KycGateway {
  SupabaseKycGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<KycSnapshot> current() async {
    final row = await _client
        .from('identity_verifications')
        .select(
          'verification_status, provider, provider_reference, document_kind, masked_last4',
        )
        .maybeSingle();
    if (row == null) {
      return KycSnapshot.notStarted;
    }
    return _snapshot(row);
  }

  @override
  Future<KycSnapshot> giveConsent(KycDocumentKind kind) async {
    final raw = await _client.rpc<dynamic>(
      'record_kyc_consent',
      params: {'p_document_kind': kind.wire},
    );
    return _fromRpc(raw);
  }

  @override
  Future<KycSnapshot> startSandbox(KycDocumentKind kind) async {
    try {
      final response = await _client.functions.invoke(
        'start-kyc',
        body: {'document_kind': kind.wire},
      );
      final data = response.data;
      if (data is Map && data['verification'] is Map) {
        return _snapshot(
          Map<String, dynamic>.from(data['verification'] as Map),
        );
      }
    } catch (_) {
      return const KycSnapshot(
        status: 'consent_given',
        provider: 'demo',
        message:
            'The sandbox function is not deployed yet. Nothing was marked verified.',
      );
    }
    return current();
  }

  KycSnapshot _fromRpc(Object? raw) {
    if (raw is! Map) {
      throw const KycFailure('The verification service did not answer.');
    }
    final body = Map<String, dynamic>.from(raw);
    if (body['ok'] != true || body['verification'] is! Map) {
      throw const KycFailure('Consent was not recorded.');
    }
    return _snapshot(Map<String, dynamic>.from(body['verification'] as Map));
  }

  KycSnapshot _snapshot(Map<String, dynamic> row) {
    final status = row['verification_status'] as String? ?? 'not_started';
    final masked = row['masked_last4'] as String?;
    return KycSnapshot(
      status: status,
      provider: row['provider'] as String? ?? 'demo',
      documentKind: row['document_kind'] as String?,
      providerReference: row['provider_reference'] as String?,
      maskedLast4: masked == null ? null : maskedLast4OrNull(masked),
      message: switch (status) {
        'verified' =>
          'Verified. No Aadhaar number or document was stored on HOMIZI.',
        'pending' => 'Pending with the provider.',
        'rejected' => 'The provider rejected this check.',
        'consent_given' => kycConsentCopy,
        _ => 'No identity check has been started.',
      },
    );
  }
}
