import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/login_confirm.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';

class _SignedOut extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.signedOut,
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _Ready extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'yash@homizi.in',
      role: AccountRole.tenant,
      homiziWire: 'tenant',
      policyVersion: '2026-10-11-draft',
    );
  }
}

class _DemoNeedsRole extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.needsRole,
      contact: 'test5@homizi.in',
      policyVersion: '2026-10-11-draft',
    );
  }
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  SessionController Function() session,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [sessionProvider.overrideWith(session)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const HomiziApp()),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('signed-out chats shows the gate and keeps the bar', (
    tester,
  ) async {
    final shots = Platform.environment['HOMIZI_SIGN_IN_GATE_SHOTS'];
    if (shots != null && shots.isNotEmpty) {
      await tester.runAsync(_loadCaptureFonts);
    }
    final container = await _pump(tester, _SignedOut.new);
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.text('Sign in to continue'), findsNothing);
    expect(find.byType(GlassyNavigationBar), findsOneWidget);

    container.read(routerProvider).go(RoutePaths.chats);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byKey(const Key('sign-in-gate')), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Priya Nair'), findsNothing);
    expect(find.text('Meera Krishnan'), findsNothing);
    expect(find.text('Ananya Iyer'), findsNothing);
    expect(find.byKey(const Key('chat-inbox-screen')), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(GlassyNavigationBar), findsOneWidget);
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      2,
    );
    final login = tester.widget<InkWell>(
      find.byKey(const Key('sign-in-gate-login')),
    );
    final ink = tester.widget<Text>(find.text('Sign in to continue'));
    expect(ink.style?.color, HomiziColors.ink);

    container.read(routerProvider).go(RoutePaths.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);

    container.read(routerProvider).go(RoutePaths.chats);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(login.onTap, isNotNull);
    if (shots != null && shots.isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 400));
      await _shoot(tester, '$shots/sign-in-gate.png');
    }
  });

  testWidgets('login and signup open auth and return to chats', (tester) async {
    final container = await _pump(tester, _SignedOut.new);
    container.read(routerProvider).go(RoutePaths.chats);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byKey(const Key('sign-in-gate-signup')));
    await tester.pump();
    await _until(tester, find.text('Create account'));
    expect(find.byKey(const Key('contact-field')), findsOneWidget);
    final signupUri = GoRouter.of(
      tester.element(find.byKey(const Key('contact-field'))),
    ).state.uri;
    expect(signupUri.path, RoutePaths.login);
    expect(signupUri.queryParameters['panel'], 'signup');
    expect(signupUri.queryParameters['redirect'], RoutePaths.chats);
    expect(find.byType(BackButton), findsOneWidget);

    container.read(routerProvider).go(RoutePaths.chats);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('sign-in-gate-login')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('contact-field')));
    expect(find.byKey(const Key('contact-field')), findsOneWidget);
    final loginUri = GoRouter.of(
      tester.element(find.byKey(const Key('contact-field'))),
    ).state.uri;
    expect(loginUri.queryParameters['panel'], 'login');
    expect(loginUri.queryParameters['redirect'], RoutePaths.chats);

    await tester.enterText(
      find.byKey(const Key('contact-field')),
      'test5@homizi.in',
    );
    await tester.ensureVisible(find.byKey(const Key('send-code')));
    await tester.tap(find.byKey(const Key('send-code')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('otp-field')), '000000');
    await tester.ensureVisible(find.byKey(const Key('verify-code')));
    await tester.tap(find.byKey(const Key('verify-code')));
    await tester.pump();
    await _until(tester, find.byKey(const Key('login-continue')));
    expect(container.read(loginConfirmHoldProvider), isTrue);
    expect(sessionIsSignedIn(container.read(sessionProvider)), isTrue);
    expect(container.read(sessionProvider).contact, 'test5@homizi.in');

    await tester.ensureVisible(find.byKey(const Key('login-continue')));
    await tester.tap(find.byKey(const Key('login-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      container.read(loginConfirmHoldProvider),
      isFalse,
      reason: container.read(routerProvider).state.uri.toString(),
    );
    await _until(tester, find.text('Priya Nair'));
    expect(container.read(routerProvider).state.uri.path, RoutePaths.chats);
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);
    expect(find.byKey(const Key('chat-inbox-screen')), findsOneWidget);
    expect(find.text('Priya Nair'), findsOneWidget);
    expect(find.text('Meera Krishnan'), findsOneWidget);
    expect(find.byType(GlassyNavigationBar), findsOneWidget);
  });

  testWidgets('a ready session and the demo session open chats', (
    tester,
  ) async {
    final ready = await _pump(tester, _Ready.new);
    ready.read(routerProvider).go(RoutePaths.chats);
    await tester.pump();
    await _until(tester, find.text('Priya Nair'));
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);
    expect(find.text('Priya Nair'), findsOneWidget);
    expect(sessionIsSignedIn(ready.read(sessionProvider)), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    final demo = await _pump(tester, _DemoNeedsRole.new);
    expect(sessionIsSignedIn(demo.read(sessionProvider)), isTrue);
    expect(demo.read(sessionProvider).contact, 'test5@homizi.in');
    demo.read(routerProvider).go(RoutePaths.chats);
    await tester.pump();
    await _until(tester, find.text('Priya Nair'));
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);
    expect(find.byKey(const Key('chat-inbox-screen')), findsOneWidget);
    expect(find.text('Priya Nair'), findsOneWidget);
  });

  testWidgets('home, search, priorities, and roommate stay open', (
    tester,
  ) async {
    final container = await _pump(tester, _SignedOut.new);
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);

    container.read(routerProvider).go(RoutePaths.searchStart);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('search-tenant-prompt')), findsOneWidget);
    expect(find.byKey(const Key('search-properties-screen')), findsNothing);
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);

    container.read(routerProvider).go(RoutePaths.priorities);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Set My Priorities'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);

    container.read(routerProvider).go(RoutePaths.roommate);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('roommate-screen')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);

    container.read(routerProvider).go('/listing/lst_koramangala');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      container.read(routerProvider).state.uri.path,
      '/listing/lst_koramangala',
    );
    expect(find.byKey(const Key('sign-in-gate')), findsNothing);
  });
}

Future<void> _shoot(WidgetTester tester, String filePath) async {
  await tester.pump();
  final view = tester.binding.renderViews.single;
  final layer = view.debugLayer;
  if (layer is! OffsetLayer) {
    throw StateError('The view has no layer to capture.');
  }
  await tester.runAsync(() async {
    final image = await layer.toImage(Offset.zero & view.size, pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
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
      : '${Platform.resolvedExecutable}/../../../artifacts/material_fonts/MaterialIcons-Regular.otf';
  final material = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(ByteData.sublistView(await File(path).readAsBytes())),
    );
  await material.load();
}
