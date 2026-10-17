import 'package:homizi/features/interest/tenant_card.dart';

class PeopleSwipeFailure implements Exception {
  const PeopleSwipeFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Host reviews of tenant profiles. Likes go through create_interest.
abstract interface class PeopleSwipeGateway {
  Future<List<TenantCard>> load();

  Future<String> like(TenantCard card);

  Future<String> pass(TenantCard card);

  Future<String> undo(TenantCard card);
}
