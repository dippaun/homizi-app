import 'package:homizi/features/discovery/domain/discovery_state.dart';
import 'package:homizi/features/interest/demo_tenants.dart';
import 'package:homizi/features/interest/people_swipe_gateway.dart';
import 'package:homizi/features/interest/tenant_card.dart';

class DemoPeopleSwipeGateway implements PeopleSwipeGateway {
  final Set<String> _hidden = {};

  @override
  Future<List<TenantCard>> load() async {
    return [
      for (final card in demoTenantCards)
        if (!_hidden.contains(card.userId)) card,
    ];
  }

  @override
  Future<String> like(TenantCard card) async {
    _hidden.add(card.userId);
    return DiscoveryCopy.demoLike;
  }

  @override
  Future<String> pass(TenantCard card) async {
    _hidden.add(card.userId);
    return DiscoveryCopy.demoPass;
  }

  @override
  Future<String> undo(TenantCard card) async {
    _hidden.remove(card.userId);
    return 'Last swipe undone on this device.';
  }
}
