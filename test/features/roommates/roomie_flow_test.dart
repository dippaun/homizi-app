import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/roommates/roomie/roomie_catalog.dart';

void main() {
  test('the roomie catalog still covers five cities for other flows', () {
    expect(roomiePeople.length, greaterThanOrEqualTo(12));
    expect(
      roomiePeople.map((person) => person.brief.city).toSet(),
      containsAll(const ['Ahmedabad', 'Bengaluru', 'Pune', 'Mumbai', 'Delhi']),
    );
    expect(
      roomiePeople.where((person) => person.likesYou).length,
      greaterThanOrEqualTo(1),
    );
  });
}
