import 'package:homizi/features/services/domain/service_catalog.dart';

abstract interface class ServiceLeadGateway {
  Future<List<ServiceLead>> listMine();

  Future<ServiceLead> submit(ServiceLeadDraft draft);

  Future<List<ServiceLead>> listForStaff();

  Future<ServiceLead> updateStatus(String id, String status);
}

class ServiceLeadFailure implements Exception {
  const ServiceLeadFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
