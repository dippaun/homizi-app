import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/tools/domain/rent_split.dart';

void main() {
  test('equal weights split rent and the pool adds back', () {
    final result = rentSplit(
      const SplitInput(
        rentInr: 30000,
        depositInr: 90000,
        maintenanceInr: 3000,
        utilitiesInr: 1500,
        shares: [
          FlatmateShare(name: 'Ananya Iyer', weight: 1),
          FlatmateShare(name: 'Meera Nair', weight: 1),
          FlatmateShare(name: 'Kabir Shah', weight: 1),
        ],
        incomeInr: 150000,
      ),
    );

    expect(result.lines.map((line) => line.rentInr), [10000, 10000, 10000]);
    expect(result.lines.map((line) => line.depositInr), [30000, 30000, 30000]);
    expect(
      result.lines.fold<int>(0, (sum, line) => sum + line.monthlyInr),
      34500,
    );
    expect(result.monthlyPool, 34500);
    expect(result.band, 'Comfortable');
  });

  test('a larger room takes the remainder rupee', () {
    final result = rentSplit(
      const SplitInput(
        rentInr: 100,
        depositInr: 0,
        maintenanceInr: 0,
        utilitiesInr: 0,
        shares: [
          FlatmateShare(name: 'Ananya', weight: 1),
          FlatmateShare(name: 'Rohan', weight: 1),
          FlatmateShare(name: 'Meera', weight: 1),
        ],
      ),
    );

    expect(
      result.lines.map((line) => line.rentInr).reduce((a, b) => a + b),
      100,
    );
    expect(result.lines.first.rentInr, 34);
    expect(result.band, isNull);
  });

  test('unequal room weights and a stretched household', () {
    final parts = splitAmount(45000, const [2, 1]);
    expect(parts, [30000, 15000]);

    final result = rentSplit(
      const SplitInput(
        rentInr: 45000,
        depositInr: 150000,
        maintenanceInr: 3500,
        utilitiesInr: 2200,
        shares: [
          FlatmateShare(name: 'Ananya Iyer', weight: 2),
          FlatmateShare(name: 'Rohan Mehta', weight: 1),
        ],
        incomeInr: 120000,
      ),
    );

    expect(result.lines.first.rentInr, 30000);
    expect(result.lines.last.depositInr, 50000);
    expect(result.monthlyPool, 50700);
    expect(result.band, 'Above a third');
    expect(affordabilityBand(30000, 100000), 'Comfortable');
    expect(affordabilityBand(35000, 100000), 'Stretch');
  });

  test('a missing flatmate is refused', () {
    expect(() => splitAmount(1000, const []), throwsArgumentError);
    expect(() => splitAmount(1000, const [0]), throwsArgumentError);
  });
}
