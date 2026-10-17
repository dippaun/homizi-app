import 'package:homizi/features/verification/domain/kyc_rules.dart';
import 'package:homizi/features/verification/kyc_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseKycGateway implements KycGateway {
  SupabaseKycGateway(this._client);

  final SupabaseClient _client;

  static const _columns =
      'verification_status, provider, provider_reference, document_kind, masked_last4, aadhaar_status, face_status';

  @override
  Future<KycSnapshot> current() async {
    try {
      final row = await _client
          .from('identity_verifications')
          .select(_columns)
          .maybeSingle();
      if (row == null) {
        return KycSnapshot.notStarted;
      }
      return _snapshot(Map<String, dynamic>.from(row));
    } catch (_) {
      return KycSnapshot.notStarted;
    }
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
  Future<KycSnapshot> start(KycDocumentKind kind) async {
    try {
      final response = await _client.functions.invoke(
        'start-kyc',
        body: {'document_kind': kind.wire},
      );
      return _fromStart(response.data);
    } on FunctionException catch (error) {
      return _fromStart(error.details);
    } catch (_) {
      return KycSnapshot.comingSoon;
    }
  }

  @override
  Future<KycSnapshot> deleteMine() async {
    final raw = await _client.rpc<dynamic>('delete_my_verification');
    if (raw is Map && raw['ok'] == true) {
      return KycSnapshot.notStarted;
    }
    throw const KycFailure('Verification data was not deleted.');
  }

  KycSnapshot _fromStart(Object? raw) {
    if (raw is! Map) {
      return KycSnapshot.comingSoon;
    }
    final body = Map<String, dynamic>.from(raw);
    if (body['error'] == 'consent_required') {
      throw const KycFailure('Consent is required before verification.');
    }
    if (body['ok'] != true || body['verification'] is! Map) {
      return KycSnapshot.comingSoon;
    }
    final gateway = body['gateway_url'];
    return _snapshot(
      Map<String, dynamic>.from(body['verification'] as Map),
      gatewayUrl: gateway is String && gateway.startsWith('https://')
          ? gateway
          : null,
    );
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

  KycSnapshot _snapshot(Map<String, dynamic> row, {String? gatewayUrl}) {
    final status = row['verification_status'] as String? ?? 'not_started';
    final aadhaar = kycCheckStateFromWire(row['aadhaar_status'] as String?);
    final face = kycCheckStateFromWire(row['face_status'] as String?);
    final masked = row['masked_last4'] as String?;
    final reference = row['provider_reference'] as String?;
    return KycSnapshot(
      status: status,
      aadhaarStatus: aadhaar,
      faceStatus: face,
      documentKind: row['document_kind'] as String?,
      providerReference: reference != null && !looksLikeRawAadhaar(reference)
          ? reference
          : null,
      maskedLast4: masked == null ? null : maskedLast4OrNull(masked),
      gatewayUrl: gatewayUrl,
      message: _message(aadhaar, face, status),
    );
  }

  String _message(KycCheckState aadhaar, KycCheckState face, String status) {
    if (aadhaar == KycCheckState.verified && face == KycCheckState.verified) {
      return 'Verified. HOMIZI stored the result and the last 4 digits only.';
    }
    if (aadhaar == KycCheckState.failed || face == KycCheckState.failed) {
      return 'Verification did not finish. You can try again.';
    }
    if (aadhaar == KycCheckState.inProgress ||
        face == KycCheckState.inProgress ||
        status == 'pending') {
      return 'Verification is in progress.';
    }
    if (status == 'consent_given') {
      return kycConsentCopy;
    }
    return 'No identity check has been started.';
  }
}
