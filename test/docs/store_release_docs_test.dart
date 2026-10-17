import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store drafts match the app and stay unsubmitted', () {
    final listing = File('docs/store/LISTING.md').readAsStringSync();
    expect(listing, contains('DRAFT — NOT FOR SUBMISSION.'));
    expect(listing, contains('House & Home'));
    final short = listing
        .split('\n')
        .firstWhere((line) => line.startsWith('Find a home'));
    expect(short.length, lessThanOrEqualTo(80));

    final safety = File('docs/store/DATA_SAFETY.md').readAsStringSync();
    expect(safety, contains('Mumbai'));
    expect(safety, contains('ap-south-1'));
    expect(safety, contains('Sentry stays off'));
    expect(safety, contains('Turn product analytics off'));
    expect(safety, contains('Do not declare Firebase Analytics'));

    final access = File('docs/store/REVIEWER_ACCESS.md').readAsStringSync();
    expect(access, contains('test@homizi.in'));
    expect(access, contains('000000'));
    expect(access, contains('config/staging.json'));

    final signing = File('docs/release/SIGNING.md').readAsStringSync();
    expect(signing, contains('key.properties'));
    expect(signing, contains('HOMIZI_UPLOAD_STORE_FILE'));
    expect(signing, contains('Play App Signing'));
    expect(signing, contains('debug'));
    expect(signing, isNot(contains('BEGIN PRIVATE KEY')));

    final android = File('docs/release/ANDROID.md').readAsStringSync();
    expect(android, contains('compileSdk'));
    expect(android, contains('**36**'));
    expect(android, contains('minSdk'));
    expect(android, contains('**26**'));

    final ci = File('docs/release/CI.md').readAsStringSync();
    expect(ci, contains('6996ebdd-3786-4add-b348-00c5de0725e1'));
    expect(ci, contains('Cursor Origin'));
    expect(ci, contains('FIREBASE_APP_ID'));
    expect(ci, contains('NETLIFY_AUTH_TOKEN'));
  });
}
