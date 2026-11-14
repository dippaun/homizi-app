import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/routing/app_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/session/demo_session_store.dart';
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

AppConfig get _config => AppConfig.parse(
  rawEnvironment: 'staging',
  supabaseUrl: '',
  supabaseAnonKey: '',
  policyVersion: '2026-10-11-draft',
);

Future<void> _pump(
  WidgetTester tester,
  SessionController Function() session,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionProvider.overrideWith(session)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Finder _nav(String label) {
  return find.descendant(
    of: find.byType(GlassyNavigationBar),
    matching: find.text(label),
  );
}

void main() {
  testWidgets('signed-out header has no menu, bell, or initials', (
    tester,
  ) async {
    await _pump(tester, _SignedOut.new);

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.byKey(const Key('home-menu')), findsNothing);
    expect(find.byKey(const Key('home-notifications')), findsNothing);
    expect(find.byKey(const Key('home-initials')), findsNothing);
    expect(find.byType(NavigationDrawer), findsNothing);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-profile')),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsOneWidget,
    );
    final button = tester.widget<IconButton>(
      find.byKey(const Key('home-profile')),
    );
    expect(
      button.style?.foregroundColor?.resolve(<WidgetState>{}),
      HomiziColors.ink,
    );
    expect(
      button.style?.side?.resolve(<WidgetState>{})?.color,
      HomiziColors.ink,
    );

    await tester.tap(find.byKey(const Key('home-profile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('auth-open-login')), findsOneWidget);
    expect(find.byKey(const Key('auth-open-signup')), findsOneWidget);
    await tester.tap(find.byKey(const Key('auth-open-login')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contact-field')), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('signed-in header keeps the menu, bell, and initials', (
    tester,
  ) async {
    await _pump(tester, _Ready.new);

    expect(find.byKey(const Key('home-menu')), findsOneWidget);
    expect(find.byKey(const Key('home-notifications')), findsOneWidget);
    expect(find.byKey(const Key('home-initials')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('home-initials')),
        matching: find.text('Y'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('home-profile')),
        matching: find.byIcon(Icons.person_outline),
      ),
      findsNothing,
    );
  });

  testWidgets('home shows the bar, Homes signed out and Roommate in', (
    tester,
  ) async {
    await _pump(tester, _SignedOut.new);
    expect(find.byType(GlassyNavigationBar), findsOneWidget);
    expect(_nav('Homes'), findsOneWidget);
    expect(_nav('Priorities'), findsNothing);
    expect(_nav('Search'), findsNothing);
    expect(_nav('Roommate'), findsNothing);
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      0,
    );

    await tester.tap(_nav('Homes'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('group-by-locality')), findsOneWidget);
    expect(find.text('Set My Priorities'), findsNothing);
    expect(find.textContaining('% Match'), findsNothing);
    expect(
      GoRouter.of(
        tester.element(find.byKey(const Key('group-by-locality'))),
      ).state.uri.path,
      RoutePaths.explore,
    );
    expect(find.byType(BackButton), findsOneWidget);
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      1,
    );
  });

  testWidgets('a signed-in tenant bar keeps Search and Priorities', (
    tester,
  ) async {
    await _pump(tester, _Ready.new);
    expect(_nav('Roommate'), findsOneWidget);
    expect(_nav('Search'), findsOneWidget);
    expect(_nav('Priorities'), findsOneWidget);
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      0,
    );
  });

  testWidgets('demo sign-in updates header and profile, then survives reload', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = MemoryDemoSessionStore();

    Future<ProviderContainer> load() async {
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(_config),
          demoSessionStoreProvider.overrideWithValue(store),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const HomiziApp(),
        ),
      );
      await tester.pump();
      await container.read(sessionProvider.notifier).finishBoot();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      return container;
    }

    final first = await load();
    first.read(routerProvider).go(RoutePaths.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.byKey(const Key('home-menu')), findsNothing);
    expect(find.byKey(const Key('home-initials')), findsNothing);
    expect(_nav('Homes'), findsOneWidget);
    expect(_nav('Priorities'), findsNothing);
    expect(_nav('Search'), findsNothing);
    expect(sessionIsSignedIn(first.read(sessionProvider)), isFalse);

    await first.read(sessionProvider.notifier).acceptConsent();
    expect(
      await first
          .read(sessionProvider.notifier)
          .signIn(contact: 'test5@homizi.in', code: '000000'),
      isNull,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(first.read(sessionProvider).phase, SessionPhase.needsRole);
    expect(first.read(forceDemoModeProvider), isTrue);
    expect(sessionIsSignedIn(first.read(sessionProvider)), isTrue);
    expect(store.value?.contact, 'test5@homizi.in');
    expect(find.byKey(const Key('home-menu')), findsOneWidget);
    expect(find.byKey(const Key('home-notifications')), findsOneWidget);
    expect(find.byKey(const Key('home-initials')), findsOneWidget);
    expect(_nav('Roommate'), findsOneWidget);
    expect(_nav('Priorities'), findsNothing);
    expect(find.text('Login / Sign Up'), findsNothing);

    first.read(routerProvider).go(RoutePaths.profile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('profile-me-screen')), findsOneWidget);
    expect(find.text('Login / Sign Up'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    first.dispose();

    final second = await load();
    addTearDown(second.dispose);
    expect(second.read(sessionProvider).phase, SessionPhase.needsRole);
    expect(second.read(sessionProvider).contact, 'test5@homizi.in');
    expect(sessionIsSignedIn(second.read(sessionProvider)), isTrue);
    second.read(routerProvider).go(RoutePaths.home);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.byKey(const Key('home-menu')), findsOneWidget);
    expect(find.byKey(const Key('home-initials')), findsOneWidget);
    expect(_nav('Roommate'), findsOneWidget);
    expect(find.text('Login / Sign Up'), findsNothing);

    second.read(routerProvider).go(RoutePaths.home);
    await tester.pump();
    await second.read(sessionProvider.notifier).signOut();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(second.read(sessionProvider).phase, SessionPhase.signedOut);
    expect(second.read(forceDemoModeProvider), isFalse);
    expect(store.value, isNull);
    expect(sessionIsSignedIn(second.read(sessionProvider)), isFalse);
    expect(find.byKey(const Key('home-menu')), findsNothing);
    expect(find.byKey(const Key('home-initials')), findsNothing);
    expect(_nav('Homes'), findsOneWidget);
    expect(_nav('Priorities'), findsNothing);
    expect(_nav('Search'), findsNothing);
  });

  testWidgets('home chrome screenshots stay opt-in', (tester) async {
    final dir = Platform.environment['HOMIZI_CHROME_SHOTS'];
    if (dir == null || dir.isEmpty) {
      expect(Platform.environment.containsKey('HOMIZI_CHROME_SHOTS'), isFalse);
      return;
    }
    await tester.runAsync(_loadCaptureFonts);
    await _capture(tester, dir, _SignedOut.new, 'home-signed-out.png');
    await _capture(tester, dir, _Ready.new, 'home-signed-in.png');
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

Future<void> _capture(
  WidgetTester tester,
  String dir,
  SessionController Function() session,
  String name,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(name),
      overrides: [sessionProvider.overrideWith(session)],
      child: const RepaintBoundary(key: Key('chrome-shot'), child: HomiziApp()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(find.byKey(const Key('home-screen')), findsOneWidget);
  if (name.contains('signed-in')) {
    expect(find.byKey(const Key('home-initials')), findsOneWidget);
    expect(find.text('Roommate'), findsOneWidget);
  } else {
    expect(find.byKey(const Key('home-menu')), findsNothing);
    expect(find.text('Homes'), findsOneWidget);
    expect(find.text('Priorities'), findsNothing);
    expect(find.text('Search'), findsNothing);
  }
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 250)),
  );
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('chrome-shot')),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    return image.toByteData(format: ui.ImageByteFormat.png);
  });
  expect(bytes, isNotNull);
  final file = File('$dir/$name');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
}
