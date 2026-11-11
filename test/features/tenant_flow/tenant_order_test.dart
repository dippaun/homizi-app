import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_catalog.dart';
import 'package:homizi/features/tenant_flow/tenant_order.dart';

void main() {
  const commute = CommuteContext(
    office: powaiOffice,
    mode: TransportMode.car,
    maxMinutes: 30,
  );

  test('priority rank changes the percent and exact matches lead', () {
    final base = orderedTenantProperties(
      priorities: const TenantPriorities(),
      commute: commute,
    );
    final flipped = orderedTenantProperties(
      priorities: const TenantPriorities().copyWith(
        order: const [
          TenantFactorId.furnishing,
          TenantFactorId.lifestyle,
          TenantFactorId.propertyType,
          TenantFactorId.gender,
          TenantFactorId.moveIn,
          TenantFactorId.location,
          TenantFactorId.occupancy,
          TenantFactorId.budget,
        ],
      ),
      commute: commute,
    );

    expect(base, isNotEmpty);
    expect(base.first.importantMismatch, isFalse);
    expect({
      for (final pick in base) pick.id: pick.percent,
    }, isNot(equals({for (final pick in flipped) pick.id: pick.percent})));

    for (var index = 0; index < base.length - 1; index++) {
      final current = base[index];
      final next = base[index + 1];
      final mismatchBeforeClean =
          current.importantMismatch && !next.importantMismatch;
      expect(mismatchBeforeClean, isFalse);
      if (!current.importantMismatch && !next.importantMismatch) {
        expect(current.percent, greaterThanOrEqualTo(next.percent));
      }
    }
  });

  test('roomies use the roommate score, highest first', () {
    final roomies = orderedTenantRoomies();
    expect(roomies, isNotEmpty);
    expect(roomies.every((pick) => pick.roomie), isTrue);
    for (var index = 0; index < roomies.length - 1; index++) {
      expect(
        roomies[index].percent,
        greaterThanOrEqualTo(roomies[index + 1].percent),
      );
    }
  });
}
