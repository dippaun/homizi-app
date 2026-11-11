import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/auth/google_logo.dart';

void main() {
  test('the Google G stays inside the 48 view box', () {
    final bounds = parseSvgPath(
      'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
    ).getBounds();
    expect(bounds.width, greaterThan(10));
    expect(bounds.left, greaterThanOrEqualTo(-0.1));
    expect(bounds.top, greaterThanOrEqualTo(-0.1));
    expect(bounds.right, lessThanOrEqualTo(48.1));
    expect(bounds.bottom, lessThanOrEqualTo(48.1));
  });

  test('the smooth curve in the yellow segment parses', () {
    final bounds = parseSvgPath(
      'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
    ).getBounds();
    expect(bounds.width, greaterThan(5));
    expect(bounds.height, greaterThan(5));
  });
}
