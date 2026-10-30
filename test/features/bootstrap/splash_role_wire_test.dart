import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/bootstrap/splash_screen.dart';

void main() {
  test('splash paths map to primary_role wires', () {
    expect(roleWireForSplashPath(RoutePaths.flowTenant), 'tenant');
    expect(roleWireForSplashPath(RoutePaths.roomie), 'roommate');
    expect(roleWireForSplashPath(RoutePaths.flowBroker), 'broker');
    expect(
      roleWireForSplashPath('${RoutePaths.flowSwipe}?deck=demand'),
      'host',
    );
  });
}
