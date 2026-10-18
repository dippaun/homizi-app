import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _Ready extends SessionController {
  _Ready(this.seed);

  final SessionState seed;

  @override
  SessionState build() => seed;
}

void main() {
  test('legacy account roles map onto the four HOMIZI roles', () {
    expect(
      homiziRoleFromLegacy(usersPrimaryRole: 'tenant'),
      HomiziRole.tenant,
    );
    expect(homiziRoleFromLegacy(usersPrimaryRole: 'host'), HomiziRole.host);
    expect(
      homiziRoleFromLegacy(usersPrimaryRole: 'host', hostCategory: 'broker'),
      HomiziRole.broker,
    );
    expect(homiziRoleFromLegacy(usersPrimaryRole: 'both'), HomiziRole.tenant);
    expect(homiziRoleFromLegacy(usersPrimaryRole: 'unset'), isNull);
    expect(
      homiziRoleFromLegacy(
        profilesPrimaryRole: 'roommate',
        usersPrimaryRole: 'tenant',
      ),
      HomiziRole.roommate,
    );
    expect(legacyUsersRoleWire(HomiziRole.roommate), 'tenant');
    expect(legacyUsersRoleWire(HomiziRole.broker), 'host');
    expect(accountRoleForHomizi(HomiziRole.broker), AccountRole.host);
  });

  test('currentRoleProvider prefers the stored profile role', () {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(
          () => _Ready(
            const SessionState(
              phase: SessionPhase.ready,
              role: AccountRole.host,
              homiziWire: 'broker',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(currentRoleProvider), HomiziRole.broker);
  });

  test('currentRoleProvider maps a legacy tenant when no wire is stored', () {
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(
          () => _Ready(
            const SessionState(
              phase: SessionPhase.ready,
              role: AccountRole.both,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(currentRoleProvider), HomiziRole.tenant);
  });
}
