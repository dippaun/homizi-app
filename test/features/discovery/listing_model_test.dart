import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/discovery/data/demo_catalog.dart';

void main() {
  test('public listing JSON has no contact or street address', () {
    final json = DemoCatalog.listings.first.toPublicJson();
    expect(json.keys, isNot(contains('phone')));
    expect(json.keys, isNot(contains('email')));
    expect(json.keys, isNot(contains('addressLine')));
    expect(json.keys, isNot(contains('aadhaar')));
  });
}
