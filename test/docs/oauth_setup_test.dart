import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('oauth setup lists the Google steps and defers Apple', () {
    final doc = File('docs/OAUTH_SETUP.md').readAsStringSync();
    expect(doc, contains('https://dippaun.github.io/homizi-app/'));
    expect(
      doc,
      contains('https://loraalfiuklespaldotd.supabase.co/auth/v1/callback'),
    );
    expect(doc, contains('OAuth consent screen'));
    expect(doc, contains('Web client ID'));
    expect(doc, contains('Web application'));
    expect(doc, contains('Client ID'));
    expect(doc, contains('Client secret'));
    expect(doc, contains('Google'));
    expect(doc, contains('Site URL'));
    expect(doc, contains('Redirect URLs'));
    expect(doc, contains('signInWithOAuth'));
    expect(doc, contains('OAuthProvider.google'));
    expect(doc, contains('ensure_own_account'));
    expect(doc, contains('/homizi-app/'));
    expect(doc, contains('Apple sign-in is deferred.'));
    expect(doc, isNot(contains('Services ID')));
    expect(doc, isNot(contains('.p8')));
    expect(doc, isNot(contains('OAuthProvider.apple')));
    expect(doc, isNot(contains('Continue with Apple')));
  });
}
