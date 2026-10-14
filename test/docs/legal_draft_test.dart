import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('privacy and terms stay marked for legal review', () {
    for (final path in ['docs/legal/PRIVACY.md', 'docs/legal/TERMS.md']) {
      final text = File(path).readAsStringSync();
      expect(text, contains('DRAFT FOR LEGAL REVIEW — not approved.'));
      expect(text.toLowerCase(), isNot(contains('approved by counsel')));
      expect(text, contains('2026-10-11-draft'));
    }
  });

  test('the store listing is not a submission', () {
    final text = File('docs/STORE_LISTING.md').readAsStringSync();
    expect(text, contains('DRAFT — NOT FOR SUBMISSION.'));
    expect(text.toLowerCase(), isNot(contains('ready for the store')));
  });
}
