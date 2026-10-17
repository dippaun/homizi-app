import 'package:homizi/features/agreements/agreement_gateway.dart';
import 'package:homizi/features/agreements/domain/agreement_rules.dart';

class DemoAgreementGateway implements AgreementGateway {
  final List<AgreementRecord> _rows = [];
  var _seq = 0;

  @override
  Future<List<AgreementRecord>> listMine() async => List.unmodifiable(_rows);

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
    if (matchId.trim().isEmpty) {
      throw const AgreementFailure('Choose a match before creating a draft.');
    }
    _seq += 1;
    final row = AgreementRecord(
      id: 'demo-agreement-$_seq',
      title: title.trim(),
      status: AgreementStatus.draft,
      provider: 'demo',
      tenantName: tenantName,
      ownerName: ownerName,
      stampAmountInr: stampAmountInr,
      sourceDraftId: sourceDraftId,
      body: body,
    );
    _rows.insert(0, row);
    return row;
  }

  @override
  Future<AgreementRecord> sendForSignature(String id) async {
    return _replace(id, (current) {
      if (current.status != AgreementStatus.draft) {
        throw const AgreementFailure('Only a draft can be sent.');
      }
      return _copy(current, status: AgreementStatus.sent);
    });
  }

  @override
  Future<AgreementRecord> demoSign(String id, {required String role}) async {
    return _replace(id, (current) {
      final next = demoStatusAfterSign(
        current: current.status,
        role: role,
        provider: current.provider,
      );
      if (next == null) {
        throw const AgreementFailure(
          'This demo signature is not available for that status.',
        );
      }
      return _copy(current, status: next, providerReference: 'demo-esign-$id');
    });
  }

  Future<AgreementRecord> _replace(
    String id,
    AgreementRecord Function(AgreementRecord current) change,
  ) async {
    final index = _rows.indexWhere((row) => row.id == id);
    if (index < 0) {
      throw const AgreementFailure('That agreement is not on this device.');
    }
    final next = change(_rows[index]);
    _rows[index] = next;
    return next;
  }

  AgreementRecord _copy(
    AgreementRecord current, {
    required AgreementStatus status,
    String? providerReference,
  }) {
    return AgreementRecord(
      id: current.id,
      title: current.title,
      status: status,
      provider: current.provider,
      tenantName: current.tenantName,
      ownerName: current.ownerName,
      providerReference: providerReference ?? current.providerReference,
      stampAmountInr: current.stampAmountInr,
      sourceDraftId: current.sourceDraftId,
      body: current.body,
    );
  }
}
