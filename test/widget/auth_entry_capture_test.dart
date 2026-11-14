import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_gateway.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/auth/auth_provider_settings.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/session/session_controller.dart';

/// Writes 390x844 (pixel ratio 2) shots of the new entry screens when
/// HOMIZI_CAPTURE_DIR is set. CI skips it.
void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('auth entry capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  setUpAll(_loadCaptureFonts);

  Future<void> shoot(WidgetTester tester, String name) async {
    await tester.pump(const Duration(milliseconds: 50));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<ProviderContainer> frame(
    WidgetTester tester,
    ProviderContainer container,
    Widget home,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 1688);
    addTearDown(tester.view.reset);
    addTearDown(container.dispose);
    final session = container.read(sessionProvider.notifier);
    await session.finishBoot();
    await session.acceptConsent();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: RepaintBoundary(key: const Key('shot-frame'), child: home),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    return container;
  }

  testWidgets('initial, forms, and the code boxes', (tester) async {
    await frame(
      tester,
      ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_prodConfig),
          authProviderSettingsProvider.overrideWith(_FixedProviders.new),
        ],
      ),
      const LoginScreen(),
    );
    await shoot(tester, '01-initial');

    await tester.tap(find.byKey(const Key('auth-open-login')));
    await tester.pumpAndSettle();
    await shoot(tester, '02-login');

    await tester.tap(find.byKey(const Key('auth-open-signup')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'ananya.sharma@homizi.in',
    );
    await tester.pump();
    await shoot(tester, '03-signup');
  });

  testWidgets('the code boxes', (tester) async {
    await frame(
      tester,
      ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_prodConfig),
          authProviderSettingsProvider.overrideWith(_FixedProviders.new),
        ],
      ),
      const LoginScreen(
        previewCooldown: 42,
        previewContact: 'ananya.sharma@homizi.in',
        previewCode: '482913',
      ),
    );
    await shoot(tester, '04-otp');
  });

  testWidgets('welcome and signup success', (tester) async {
    final container = await frame(
      tester,
      ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_devConfig),
          accountGatewayProvider.overrideWithValue(DemoAccountGateway()),
          authProviderSettingsProvider.overrideWith(_FixedProviders.new),
        ],
      ),
      const LoginScreen(),
    );
    await tester.tap(find.byKey(const Key('auth-open-login')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'ananya.sharma@homizi.in',
    );
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();
    await shoot(tester, '05-welcome');

    container.read(sessionProvider.notifier);
    await container.read(sessionProvider.notifier).signOut();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    final again = await frame(
      tester,
      ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_devConfig),
          accountGatewayProvider.overrideWithValue(DemoAccountGateway()),
          authProviderSettingsProvider.overrideWith(_FixedProviders.new),
        ],
      ),
      const LoginScreen(),
    );
    await tester.tap(find.byKey(const Key('auth-open-signup')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'meera.iyer@homizi.in',
    );
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.ensureVisible(find.byKey(const Key('verify-code')));
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pumpAndSettle();
    await shoot(tester, '06-signup-success');
    expect(again.read(sessionProvider).contact, isNotEmpty);
  });

  testWidgets('rate limit copy', (tester) async {
    await frame(
      tester,
      ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            AppConfig.parse(
              rawEnvironment: 'prod',
              supabaseUrl: 'https://loraalfiuklespaldotd.supabase.co',
              supabaseAnonKey: 'sb_publishable_example',
              policyVersion: '2026-10-11-draft',
            ),
          ),
          accountGatewayProvider.overrideWithValue(_RateLimitGateway()),
          authProviderSettingsProvider.overrideWith(_FixedProviders.new),
        ],
      ),
      const LoginScreen(),
    );
    await tester.tap(find.byKey(const Key('auth-open-login')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'ananya.sharma@homizi.in',
    );
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.pump();
    await shoot(tester, '07-rate-limit');
  });
}

const _prodConfig = AppConfig(
  environment: AppEnvironment.prod,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
);

const _devConfig = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
);

class _FixedProviders extends AuthProviderSettingsController {
  @override
  AuthProviderSettings build() =>
      const AuthProviderSettings(google: false, phone: false);
}

class _RateLimitGateway extends DemoAccountGateway {
  @override
  Future<void> requestEmailOtp({required String email}) async {
    throw const AccountFailure(
      'over_email_send_rate_limit: supabase email rate limit exceeded',
    );
  }
}

Future<void> _loadCaptureFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();
  final inter = FontLoader('Inter');
  for (final name in const [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    inter.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await inter.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  final path = root != null && root.isNotEmpty
      ? '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
      : '${Platform.resolvedExecutable}/../../../artifacts/material_fonts/MaterialIcons-Regular.otf';
  final material = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(await File(path).readAsBytes())),
    );
  await material.load();
}
