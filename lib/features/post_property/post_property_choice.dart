import 'package:homizi/features/roles/role_provider.dart';

/// How the person wants to list on HOMIZI.
enum PostPropertyChoice { owner, partner, shared }

/// Host lists as an owner, a property partner (broker) lists as a partner,
/// and a home-sharer lists a shared room. Tenant and an empty role wait
/// for a tap.
PostPropertyChoice? choiceForRole(HomiziRole? role) {
  return switch (role) {
    HomiziRole.host => PostPropertyChoice.owner,
    HomiziRole.broker => PostPropertyChoice.partner,
    HomiziRole.roommate => PostPropertyChoice.shared,
    HomiziRole.tenant || null => null,
  };
}

/// `PP20261115-4587`. The four digits are the supplied suffix, not a guess.
String partnerApplicationId(DateTime when, int suffix) {
  final year = when.year.toString().padLeft(4, '0');
  final month = when.month.toString().padLeft(2, '0');
  final day = when.day.toString().padLeft(2, '0');
  final tail = (suffix.abs() % 10000).toString().padLeft(4, '0');
  return 'PP$year$month$day-$tail';
}
