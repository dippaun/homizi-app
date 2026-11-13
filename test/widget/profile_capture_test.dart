import 'dart:convert';
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
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/profile/domain/profile_activity.dart';
import 'package:homizi/features/profile/profile_hub_gateway.dart';
import 'package:homizi/features/profile/profile_hub_providers.dart';
import 'package:homizi/features/profile/profile_me_screen.dart';
import 'package:homizi/features/profile_create/profile_create_screen.dart';
import 'package:homizi/features/profile_create/profile_create_store.dart';
import 'package:homizi/features/profile_create/profile_image_source.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

const _demoConfig = AppConfig(
  environment: AppEnvironment.dev,
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
  demoSkipLogin: true,
);

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

class _Camera implements ProfileImageSource {
  @override
  Future<Uint8List?> captureSelfie() async => _png;

  @override
  Future<Uint8List?> pickProfilePhoto() async => _png;
}

class _Ready extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _EmptyActivity implements ProfileHubGateway {
  @override
  Future<ProfileActivity> loadActivity() async => ProfileActivity.empty;
}

void main() {
  testWidgets('profile screenshots at 390x844 scale 2', (tester) async {
    final dir = Platform.environment['HOMIZI_PROFILE_SHOTS'];
    if (dir == null || dir.isEmpty) {
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = ProfileCreateStore(DemoAccountGateway());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          profileCreateStoreProvider.overrideWith((ref) => store),
          profileImageSourceProvider.overrideWithValue(_Camera()),
          sessionProvider.overrideWith(_Ready.new),
          profileHubGatewayProvider.overrideWithValue(_EmptyActivity()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const ProfileCreateScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> shoot(String name, Key boundary) async {
      final scrollable = find.descendant(
        of: find.byKey(boundary),
        matching: find.byWidgetPredicate(
          (widget) => widget is Scrollable && widget.axis == Axis.vertical,
        ),
      );
      if (scrollable.evaluate().isNotEmpty) {
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      }
      await tester.pump();
      final box = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundary),
      );
      await tester.runAsync(() async {
        final image = await box.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> next() async {
      final finder = find.byKey(const Key('profile-create-continue'));
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> reveal(Finder finder) async {
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.descendant(
          of: find.byKey(const Key('profile-create-shot')),
          matching: find.byWidgetPredicate(
            (widget) => widget is Scrollable && widget.axis == Axis.vertical,
          ),
        ),
      );
      await tester.pump();
    }

    await shoot('01-role', const Key('profile-create-shot'));
    await tester.tap(find.byKey(const Key('profile-role-tenant')));
    await tester.tap(find.byKey(const Key('profile-role-sharer')));
    await tester.pump();
    await shoot('02-role-selected', const Key('profile-create-shot'));
    await next();
    await shoot('03-basic', const Key('profile-create-shot'));
    await tester.enterText(
      find.byKey(const Key('profile-create-full-name')),
      'Priya Shah',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-nickname')),
      'Asha',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-surname')),
      'Mehta',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-dob-day')),
      '12',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-dob-month')),
      '12',
    );
    await tester.enterText(
      find.byKey(const Key('profile-create-dob-year')),
      '2000',
    );
    await reveal(find.byKey(const Key('profile-create-gender-Woman')));
    await tester.tap(find.byKey(const Key('profile-create-gender-Woman')));
    await tester.pump();
    await reveal(find.byKey(const Key('profile-create-occupation')));
    await tester.tap(find.byKey(const Key('profile-create-occupation')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Student').last);
    await tester.pump();
    await shoot('04-basic-filled', const Key('profile-create-shot'));
    await next();
    await shoot('05-languages', const Key('profile-create-shot'));
    await tester.tap(find.byKey(const Key('profile-language-Hindi')));
    await tester.tap(find.byKey(const Key('profile-language-English')));
    await tester.pump();
    await next();
    await shoot('06-contact', const Key('profile-create-shot'));
    await tester.enterText(
      find.byKey(const Key('profile-create-mobile')),
      '9876543210',
    );
    await tester.tap(find.byKey(const Key('profile-create-mobile-send')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('profile-create-mobile-otp')),
      '000000',
    );
    await tester.tap(find.byKey(const Key('profile-create-mobile-verify')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('profile-create-email')),
      'asha@example.com',
    );
    await tester.ensureVisible(
      find.byKey(const Key('profile-create-email-send')),
    );
    await tester.tap(find.byKey(const Key('profile-create-email-send')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('profile-create-email-otp')),
      '000000',
    );
    await tester.ensureVisible(
      find.byKey(const Key('profile-create-email-verify')),
    );
    await tester.tap(find.byKey(const Key('profile-create-email-verify')));
    await tester.pump();
    await shoot('07-contact-verified', const Key('profile-create-shot'));
    await next();
    await shoot('08-aadhaar', const Key('profile-create-shot'));
    await next();
    await tester.tap(find.byKey(const Key('profile-create-alert-ok')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await shoot('09-aadhaar-unavailable', const Key('profile-create-shot'));
    await next();
    await shoot('10-selfie', const Key('profile-create-shot'));
    await tester.ensureVisible(find.byKey(const Key('profile-create-capture')));
    await tester.tap(find.byKey(const Key('profile-create-capture')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await shoot('11-selfie-captured', const Key('profile-create-shot'));
    await next();
    await shoot('12-photo', const Key('profile-create-shot'));
    await tester.tap(find.byKey(const Key('profile-create-use-selfie')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await shoot('13-photo-from-selfie', const Key('profile-create-shot'));
    await next();
    await shoot('14-lifestyle', const Key('profile-create-shot'));
    await reveal(find.byKey(const Key('profile-smoking-No')));
    await tester.tap(find.byKey(const Key('profile-smoking-No')));
    await reveal(find.byKey(const Key('profile-drinking-No')));
    await tester.tap(find.byKey(const Key('profile-drinking-No')));
    await reveal(find.byKey(const Key('profile-food-Veg')));
    await tester.tap(find.byKey(const Key('profile-food-Veg')));
    await reveal(find.byKey(const Key('profile-cooking-Cook myself')));
    await tester.tap(find.byKey(const Key('profile-cooking-Cook myself')));
    await reveal(find.byKey(const Key('profile-cleaning-Myself')));
    await tester.tap(find.byKey(const Key('profile-cleaning-Myself')));
    await tester.pump();
    await next();
    await shoot('15-terms', const Key('profile-create-shot'));
    await reveal(find.byKey(const Key('profile-terms')));
    await tester.tap(find.byKey(const Key('profile-terms')));
    await reveal(find.byKey(const Key('profile-privacy')));
    await tester.tap(find.byKey(const Key('profile-privacy')));
    await reveal(find.byKey(const Key('profile-consent')));
    await tester.tap(find.byKey(const Key('profile-consent')));
    await tester.pump();
    await next();
    await shoot('16-completed', const Key('profile-create-shot'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(_demoConfig),
          profileCreateStoreProvider.overrideWith((ref) => store),
          profileImageSourceProvider.overrideWithValue(_Camera()),
          sessionProvider.overrideWith(_Ready.new),
          profileHubGatewayProvider.overrideWithValue(_EmptyActivity()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          home: const ProfileMeScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await shoot('17-dashboard-tenant', const Key('profile-me-shot'));
    await tester.ensureVisible(
      find.byKey(const Key('profile-tab-Preferences')),
    );
    await tester.tap(find.byKey(const Key('profile-tab-Preferences')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await shoot('17b-priorities-entry', const Key('profile-me-shot'));
    await tester.tap(find.byKey(const Key('profile-role-switch')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shoot('18-dashboard-host', const Key('profile-me-shot'));
    await tester.ensureVisible(
      find.byKey(const Key('profile-tab-Verification')),
    );
    await tester.tap(find.byKey(const Key('profile-tab-Verification')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await shoot('19-verification', const Key('profile-me-shot'));
  });
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
  final icons = File(_materialIconsPath());
  final material = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
  await material.load();
}

String _materialIconsPath() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    return '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  }
  return '${Platform.resolvedExecutable}/../../../artifacts/material_fonts/MaterialIcons-Regular.otf';
}
