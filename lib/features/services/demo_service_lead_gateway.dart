import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/services/service_lead_gateway.dart';

class DemoServiceLeadGateway implements ServiceLeadGateway {
  final List<ServiceLead> _rows = [];
  var _seq = 0;

  @override
  Future<List<ServiceLead>> listMine() async => List.unmodifiable(_rows);

  @override
  Future<ServiceLead> submit(ServiceLeadDraft draft) async {
    final problem = validateServiceLead(draft);
    if (problem != null) {
      throw ServiceLeadFailure(problem);
    }
    _seq += 1;
    final lead = ServiceLead(
      id: 'demo-lead-$_seq',
      kind: draft.kind,
      fromLocality: draft.fromLocality.trim(),
      toLocality: draft.toLocality?.trim(),
      city: draft.city,
      requestedOn: draft.requestedOn,
      homeSize: draft.homeSize,
      notes: draft.notes?.trim(),
      status: 'requested',
    );
    _rows.insert(0, lead);
    return lead;
  }

  @override
  Future<List<ServiceLead>> listForStaff() async => List.unmodifiable(_rows);

  @override
  Future<ServiceLead> updateStatus(String id, String status) async {
    if (!serviceLeadStatuses.contains(status)) {
      throw const ServiceLeadFailure('That status is not used.');
    }
    final index = _rows.indexWhere((row) => row.id == id);
    if (index < 0) {
      throw const ServiceLeadFailure('That request is not on this device.');
    }
    final current = _rows[index];
    final next = ServiceLead(
      id: current.id,
      kind: current.kind,
      fromLocality: current.fromLocality,
      toLocality: current.toLocality,
      city: current.city,
      requestedOn: current.requestedOn,
      homeSize: current.homeSize,
      notes: current.notes,
      status: status,
    );
    _rows[index] = next;
    return next;
  }
}
