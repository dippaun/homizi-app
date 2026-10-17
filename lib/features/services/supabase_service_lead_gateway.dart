import 'package:homizi/features/services/domain/service_catalog.dart';
import 'package:homizi/features/services/service_lead_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseServiceLeadGateway implements ServiceLeadGateway {
  SupabaseServiceLeadGateway(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, service_kind, from_locality, to_locality, city, requested_on, home_size, notes, status';

  @override
  Future<List<ServiceLead>> listMine() async {
    final rows = await _client
        .from('service_leads')
        .select(_columns)
        .order('created_at', ascending: false);
    return [
      for (final raw in rows) _lead(Map<String, dynamic>.from(raw as Map)),
    ];
  }

  @override
  Future<ServiceLead> submit(ServiceLeadDraft draft) async {
    final problem = validateServiceLead(draft);
    if (problem != null) {
      throw ServiceLeadFailure(problem);
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ServiceLeadFailure('Sign in before sending a request.');
    }
    final row = await _client
        .from('service_leads')
        .insert({
          'user_id': user.id,
          'service_kind': draft.kind.wire,
          'from_locality': draft.fromLocality.trim(),
          'to_locality': draft.kind.asksForDestination
              ? draft.toLocality?.trim()
              : null,
          'city': draft.city,
          'requested_on': _day(draft.requestedOn),
          'home_size': draft.homeSize,
          'notes': _blank(draft.notes),
          'contact_consent': true,
          'status': 'requested',
        })
        .select(_columns)
        .single();
    return _lead(row);
  }

  @override
  Future<List<ServiceLead>> listForStaff() => listMine();

  @override
  Future<ServiceLead> updateStatus(String id, String status) async {
    if (!serviceLeadStatuses.contains(status)) {
      throw const ServiceLeadFailure('That status is not used.');
    }
    final row = await _client
        .from('service_leads')
        .update({
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id)
        .select(_columns)
        .maybeSingle();
    if (row == null) {
      throw const ServiceLeadFailure('That request could not be updated.');
    }
    return _lead(row);
  }

  ServiceLead _lead(Map<String, dynamic> row) {
    final kind = serviceKindFromWire(row['service_kind'] as String?);
    final day = DateTime.tryParse(row['requested_on'] as String? ?? '');
    if (kind == null || day == null || row['id'] is! String) {
      throw const ServiceLeadFailure('That request was incomplete.');
    }
    return ServiceLead(
      id: row['id'] as String,
      kind: kind,
      fromLocality: row['from_locality'] as String? ?? '',
      toLocality: row['to_locality'] as String?,
      city: row['city'] as String? ?? '',
      requestedOn: day,
      homeSize: row['home_size'] as String?,
      notes: row['notes'] as String?,
      status: row['status'] as String? ?? 'requested',
    );
  }

  String _day(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String? _blank(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
