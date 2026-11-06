import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/tools/domain/smart_move.dart';

void main() {
  setUp(SmartMoveInterestStore.instance.clear);

  test('five years of 20k rent returns 70% in the sketch', () {
    final result = smartMove(
      const SmartMoveInput(monthlyRentInr: 20000, years: 5),
    );

    expect(result.months, 60);
    expect(result.totalRentPaidInr, 1200000);
    expect(result.estimatedReturnInr, 840000);
    expect(result.depreciatedInr, 360000);
  });

  test('bad years are refused', () {
    expect(
      () => smartMove(const SmartMoveInput(monthlyRentInr: 20000, years: 0)),
      throwsArgumentError,
    );
  });

  test('interest store keeps a local demo row', () {
    final store = SmartMoveInterestStore.instance;
    final row = store.save(
      name: 'Ananya Iyer',
      city: 'Ahmedabad',
      contact: 'ananya@homizi.in',
      monthlyRentInr: 20000,
      notes: 'Might move in 2 years',
    );

    expect(row.city, 'Ahmedabad');
    expect(store.rows, hasLength(1));
    expect(
      store.validate(
        name: '',
        city: 'Ahmedabad',
        contact: 'x',
        monthlyRentInr: 1,
      ),
      'Enter your name.',
    );
  });
}
