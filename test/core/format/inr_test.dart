import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/format/inr.dart';

void main() {
  test('groups rupees the Indian way', () {
    expect(formatInr(100), '₹100');
    expect(formatInr(1000), '₹1,000');
    expect(formatInr(22000), '₹22,000');
    expect(formatInr(1500000), '₹15,00,000');
    expect(formatInr(-9000), '-₹9,000');
  });
}
