import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/auth/auth_contact_mode.dart';
import 'package:homizi/features/auth/login_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _SignedOut extends SessionController {
  @override
  SessionState build() => const SessionState(phase: SessionPhase.signedOut);
}

void main() {
  test('digits are a mobile and an @ sign is an email', () {
    expect(readAuthContact('').mode, AuthContactMode.unknown);
    expect(readAuthContact('9876543210').isPhone, isTrue);
    expect(readAuthContact('9876543210').phoneE164, '+919876543210');
    expect(readAuthContact('meera.nair@homizi.in').isEmail, isTrue);
    expect(readAuthContact('98a').mode, AuthContactMode.unknown);
  });

  testWidgets('the unified field shows +91 for a mobile and email copy', (
    tester,
  ) async {
    if ((Platform.environment['HOMIZI_CAPTURE_DIR'] ?? '').isNotEmpty) {
      await tester.runAsync(_loadCaptureFonts);
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Find the place which you deserve'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.byKey(const Key('auth-phone-prefix')), findsNothing);
    await _shoot(tester, '02-sign-in');
    expect(find.byType(BackButton), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('contact-field')),
      '9876543210',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-phone-prefix')), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
    await _shoot(tester, '03-phone');
    expect(find.text('Send code to email'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'meera.nair@homizi.in',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-phone-prefix')), findsNothing);
    expect(find.text('Send code to email'), findsOneWidget);
    expect(find.text('+91'), findsNothing);
    await _shoot(tester, '04-email');
  });

  testWidgets('a signed-out home lists flats without search or match scores', (
    tester,
  ) async {
    if ((Platform.environment['HOMIZI_CAPTURE_DIR'] ?? '').isNotEmpty) {
      await tester.runAsync(_loadCaptureFonts);
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_SignedOut.new)],
        child: const HomiziApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('home-guest-flats')), findsOneWidget);
    expect(find.text('Available flats'), findsOneWidget);
    expect(find.byKey(const Key('home-rentals')), findsOneWidget);
    expect(find.text('Search Properties'), findsNothing);
    expect(find.text('Priorities'), findsNothing);
    expect(find.text('Search'), findsNothing);
    expect(find.textContaining('% Match'), findsNothing);
    expect(find.text('Best matches for you'), findsNothing);
    expect(find.byKey(const Key('home-card-search')), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    await _shoot(tester, '01-signed-out-flats');
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
      : '${File(Platform.resolvedExecutable).parent.parent.parent.path}/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final icons = File(path);
  if (!icons.existsSync()) {
    return;
  }
  final material = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
  await material.load();
}

Future<void> _shoot(WidgetTester tester, String name) async {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    return;
  }
  await tester.pumpAndSettle();
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer;
  if (layer is! OffsetLayer) {
    return;
  }
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$dir/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
