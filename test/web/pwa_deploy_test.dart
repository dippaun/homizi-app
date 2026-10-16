import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/auth/magic_link.dart';

void main() {
  test('web sign-in does not use the custom scheme', () {
    expect(passwordSignupRedirect(isWeb: false), magicLinkRedirect);
    expect(passwordSignupRedirect(isWeb: true), isNull);
    expect(
      passwordSignupRedirect(isWeb: true),
      isNot(contains('in.homizi.app://')),
    );
  });

  test('the PWA manifest installs HOMIZI in portrait', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(manifest['name'], 'HOMIZI');
    expect(manifest['short_name'], 'HOMIZI');
    expect(manifest['display'], 'standalone');
    expect(manifest['orientation'], 'portrait');
    expect(manifest['background_color'], '#FFFFFF');
    expect(manifest['theme_color'], '#FFFFFF');
    final icons = manifest['icons'] as List<dynamic>;
    expect(icons.length, greaterThanOrEqualTo(2));
    for (final icon in icons) {
      final map = icon as Map<String, dynamic>;
      final src = map['src'] as String;
      final file = File('web/$src');
      expect(file.existsSync(), isTrue, reason: src);
      expect(file.lengthSync(), greaterThan(32), reason: src);
    }
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('manifest.json'));
    expect(index, contains('#FFFFFF'));
    expect(index, contains('HOMIZI'));
  });

  test('Netlify publishes the web build and keeps client routes', () {
    final toml = File('netlify.toml').readAsStringSync();
    expect(toml, contains('publish = "build/web"'));
    expect(toml, contains('from = "/*"'));
    expect(toml, contains('to = "/index.html"'));
    expect(toml, contains('status = 200'));
    final redirects = File('web/_redirects').readAsStringSync();
    expect(redirects, contains('/*'));
    expect(redirects, contains('/index.html'));
    expect(redirects, contains('200'));
    final script = File('tool/deploy_web.sh').readAsStringSync();
    expect(script, contains('NETLIFY_AUTH_TOKEN'));
    expect(script, contains('NETLIFY_SITE_ID'));
    expect(
      script,
      contains(
        'flutter build web --release --dart-define-from-file=config/staging.json',
      ),
    );
    expect(script, contains('npx netlify-cli deploy --prod --dir=build/web'));
  });
}
