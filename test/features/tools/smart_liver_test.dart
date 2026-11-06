import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/tools/domain/smart_liver.dart';

void main() {
  test('healthy rent is about 25–30% of take-home', () {
    final result = smartLiver(const SmartLiverInput(monthlyIncomeInr: 60000));

    expect(result.rentMinInr, 15000);
    expect(result.rentMaxInr, 18000);
    expect(result.remainingAfterEmisInr, 60000);
    expect(result.tip, contains('25–30%'));
  });

  test('other EMIs shrink the healthy cap', () {
    final result = smartLiver(
      const SmartLiverInput(monthlyIncomeInr: 60000, otherEmisInr: 40000),
    );

    expect(result.remainingAfterEmisInr, 20000);
    // 30% of income is 18k; 70% of remaining is 14k, so the cap drops.
    expect(result.rentMaxInr, 14000);
    expect(result.rentMinInr, 14000);
    expect(result.tip, contains('EMIs'));
  });

  test('zero income is refused', () {
    expect(
      () => smartLiver(const SmartLiverInput(monthlyIncomeInr: 0)),
      throwsArgumentError,
    );
  });

  test('roundRentInr uses 500 steps', () {
    expect(roundRentInr(15240), 15000);
    expect(roundRentInr(15760), 16000);
    expect(roundRentInr(0), 0);
  });
}
