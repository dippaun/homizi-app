import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/discovery/explore_screen.dart';
import 'package:homizi/features/interest/swipe_screen.dart';
import 'package:homizi/features/matches/matches_screen.dart';
import 'package:homizi/features/saved/saved_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

Future<void> _pumpHome(WidgetTester tester, {Size? size}) async {
  await tester.runAsync(_loadCaptureFonts);
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    ProviderScope(
      key: ValueKey(size),
      overrides: [sessionProvider.overrideWith(_ReadySession.new)],
      child: const HomiziApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Finder _nav(String label) {
  return find.descendant(
    of: find.byType(NavigationBar),
    matching: find.text(label),
  );
}

Future<void> _backHome(WidgetTester tester, GoRouter router) async {
  router.go(RoutePaths.home);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _openCard(
  WidgetTester tester,
  GoRouter router,
  Key key,
  Finder arrived,
) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  expect(arrived, findsWidgets);
  await _backHome(tester, router);
  expect(find.byKey(const Key('home-screen')), findsOneWidget);
}

Finder _appBarTitle(String title) {
  return find.descendant(of: find.byType(AppBar), matching: find.text(title));
}

void main() {
  testWidgets('the bar has five destinations and Home is selected', (
    tester,
  ) async {
    await _pumpHome(tester);
    expect(find.text('Everything for your next home'), findsOneWidget);
    expect(find.byKey(const Key('home-screen')), findsOneWidget);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(5));
    expect(bar.selectedIndex, 0);
    expect(_nav('Home'), findsOneWidget);
    expect(_nav('Explore'), findsOneWidget);
    expect(_nav('Roommates'), findsOneWidget);
    expect(_nav('Swipe'), findsOneWidget);
    expect(_nav('Matches'), findsOneWidget);
    expect(_nav('Saved'), findsNothing);
    expect(find.byKey(const Key('open-saved')), findsOneWidget);

    await tester.tap(_nav('Explore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(_nav('Swipe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SwipeScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );

    await tester.tap(_nav('Matches'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(MatchesScreen), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      4,
    );

    await tester.tap(_nav('Roommates'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('roommate-screen')), findsOneWidget);

    await tester.tap(_nav('Home'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Everything for your next home'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('every home card opens the matching screen', (tester) async {
    await _pumpHome(tester, size: const Size(390, 844));
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));

    await _openCard(
      tester,
      router,
      const Key('home-find'),
      find.byType(ExploreScreen),
    );
    await _openCard(
      tester,
      router,
      const Key('home-list'),
      _appBarTitle('List your home'),
    );
    await _openCard(
      tester,
      router,
      const Key('home-swipe'),
      find.byType(SwipeScreen),
    );
    await _openCard(
      tester,
      router,
      const Key('home-tools'),
      _appBarTitle('Tools'),
    );
    await _openCard(
      tester,
      router,
      const Key('home-verify'),
      _appBarTitle('Verify identity'),
    );
    await _openCard(
      tester,
      router,
      const Key('home-pay'),
      _appBarTitle('Pay rent'),
    );

    await tester.tap(find.byKey(const Key('home-chat')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(MatchesScreen), findsOneWidget);
    await _backHome(tester, router);

    await tester.tap(find.byKey(const Key('home-profile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_appBarTitle('Profile'), findsWidgets);
    await _backHome(tester, router);

    await tester.tap(find.byKey(const Key('home-menu')));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationDrawer), findsOneWidget);
    final settings = find.descendant(
      of: find.byType(NavigationDrawer),
      matching: find.text('Settings'),
    );
    await tester.scrollUntilVisible(
      settings,
      200,
      scrollable: find.descendant(
        of: find.byType(NavigationDrawer),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(settings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_appBarTitle('Settings'), findsWidgets);
  });

  testWidgets('each home service opens its own screen', (tester) async {
    await _pumpHome(tester, size: const Size(390, 844));
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));

    await _openCard(
      tester,
      router,
      const Key('home-agreement'),
      _appBarTitle('Rent agreement'),
    );
    await _openCard(
      tester,
      router,
      const Key('home-packers'),
      _appBarTitle('Packers and movers'),
    );
    await _openCard(
      tester,
      router,
      const Key('home-cleaning'),
      _appBarTitle('Cleaning'),
    );
    await _openCard(
      tester,
      router,
      const Key('home-ac'),
      _appBarTitle('AC repair'),
    );
    await _openCard(
      tester,
      router,
      const Key('home-plumbing'),
      _appBarTitle('Plumbing'),
    );
    await _openCard(
      tester,
      router,
      const Key('home-legal'),
      _appBarTitle('Help'),
    );
    expect(find.byKey(const Key('home-service-dots')), findsOneWidget);

    expect(find.text('Verified homes, zero brokerage'), findsOneWidget);
    expect(find.text('Flats, PGs & flatmates'), findsOneWidget);
    expect(find.text('Verified tenants only'), findsOneWidget);
    expect(find.text('Right to like, left to pass'), findsOneWidget);
    expect(find.text('Pay by UPI or card'), findsOneWidget);
    expect(find.text('Instant receipts'), findsOneWidget);
    expect(find.text('Legal help'), findsOneWidget);
    expect(find.textContaining('Razorpay'), findsNothing);
    expect(find.textContaining('test mode'), findsNothing);
    expect(find.textContaining('six steps'), findsNothing);

    final texts = tester.widgetList<Text>(
      find.descendant(
        of: find.byKey(const Key('home-screen')),
        matching: find.byType(Text),
      ),
    );
    for (final text in texts) {
      expect(
        text.overflow,
        isNot(TextOverflow.ellipsis),
        reason: text.data ?? text.textSpan?.toPlainText(),
      );
    }

    final findBox = tester.getRect(find.byKey(const Key('home-find')));
    final listBox = tester.getRect(find.byKey(const Key('home-list')));
    final swipeBox = tester.getRect(find.byKey(const Key('home-swipe')));
    expect(listBox.left, swipeBox.left);
    expect(listBox.right, swipeBox.right);
    expect(findBox.top, listBox.top);
    expect(findBox.bottom, swipeBox.bottom);
    expect(listBox.left - findBox.right, 16);
    expect(swipeBox.top - listBox.bottom, 16);

    final services = tester.getSize(find.byKey(const Key('home-services')));
    final row = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('home-services')),
        matching: find.byType(Scrollable),
      ),
    );
    row.position.jumpTo(0);
    await tester.pump();
    final agreement = tester.getSize(find.byKey(const Key('home-agreement')));
    expect(agreement.width, lessThan(services.width - 24));
    expect(row.position.maxScrollExtent, greaterThan(24));
  });

  testWidgets('home does not overflow from 320 to 430', (tester) async {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      await _pumpHome(tester, size: Size(width, 700));
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('home-find')), findsOneWidget);

      final pay = find.byKey(const Key('home-pay'));
      for (var step = 0; step < 8; step++) {
        if (pay.hitTestable().evaluate().isNotEmpty) {
          break;
        }
        await tester.drag(
          find.byKey(const Key('home-scroll')),
          const Offset(0, -280),
        );
        await tester.pump();
      }
      expect(pay.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.byKey(const Key('home-services')));
      await tester.drag(
        find.byKey(const Key('home-services')),
        const Offset(-280, 0),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.drag(
        find.byKey(const Key('home-scroll')),
        const Offset(0, -900),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsOneWidget);
    }
  });

  testWidgets('deep links still open the existing tabs', (tester) async {
    await _pumpHome(tester);
    final router = GoRouter.of(tester.element(find.byType(NavigationBar)));

    router.go(RoutePaths.explore);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(ExploreScreen), findsOneWidget);
    expect(find.text('Showing 8 of 57'), findsOneWidget);

    router.go(RoutePaths.discover);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SwipeScreen), findsOneWidget);

    router.go(RoutePaths.matches);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(MatchesScreen), findsOneWidget);

    router.go(RoutePaths.saved);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(SavedScreen), findsOneWidget);

    router.go('/listing/lst_koramangala');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('contact-gate')), findsOneWidget);
  });

  testWidgets('home screenshots stay opt-in', (tester) async {
    final dir = Platform.environment['HOMIZI_HOME_SHOTS'];
    if (dir == null || dir.isEmpty) {
      expect(Platform.environment.containsKey('HOMIZI_HOME_SHOTS'), isFalse);
      return;
    }

    Future<void> shoot(String name, {Rect? crop}) async {
      await tester.pump();
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('shot-frame')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        ui.Image output = image;
        if (crop != null) {
          final recorder = ui.PictureRecorder();
          final canvas = Canvas(recorder);
          final source = Rect.fromLTWH(
            crop.left * 2,
            crop.top * 2,
            crop.width * 2,
            crop.height * 2,
          );
          canvas.drawImageRect(
            image,
            source,
            Rect.fromLTWH(0, 0, source.width, source.height),
            Paint(),
          );
          final picture = recorder.endRecording();
          output = await picture.toImage(
            source.width.ceil(),
            source.height.ceil(),
          );
          picture.dispose();
        }
        final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$dir/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        output.dispose();
        if (!identical(output, image)) image.dispose();
      });
    }

    Widget frame(Widget child) {
      return RepaintBoundary(key: const Key('shot-frame'), child: child);
    }

    await tester.runAsync(_loadCaptureFonts);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_ReadySession.new)],
        child: frame(const HomiziApp()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(find.text('Everything for your next home'), findsOneWidget);

    final vertical = tester
        .stateList<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('home-scroll')),
            matching: find.byType(Scrollable),
          ),
        )
        .firstWhere((state) => state.position.axis == Axis.vertical);
    final extent = vertical.position.maxScrollExtent;
    if (extent > 0) {
      tester.view.physicalSize = Size(390, 844 + extent);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('home-pay')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await _expectIconHasGaps(tester);
    await shoot('home-tab-full');

    final shot = tester.renderObject<RenderBox>(
      find.byKey(const Key('shot-frame')),
    );
    final nav = tester.renderObject<RenderBox>(find.byType(NavigationBar));
    final origin = nav.localToGlobal(Offset.zero, ancestor: shot);
    await shoot('home-nav', crop: origin & nav.size);
  });
}

Future<void> _loadCaptureFonts() async {
  final sans = FontLoader('PlusJakartaSans');
  for (final name in const [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$name').readAsBytes();
    sans.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await sans.load();

  final icons = File(_materialIconsPath());
  if (!icons.existsSync()) {
    throw StateError('MaterialIcons font missing at ${icons.path}');
  }
  final material = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(await icons.readAsBytes())));
  await material.load();
}

String _materialIconsPath() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    return '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  }
  final cache = File(Platform.resolvedExecutable).parent.parent.parent;
  return '${cache.path}/artifacts/material_fonts/MaterialIcons-Regular.otf';
}

/// A missing icon font paints a solid box. The menu glyph is three bars, so
/// the light gaps outnumber the ink.
Future<void> _expectIconHasGaps(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const Key('shot-frame')),
  );
  final icon = tester.renderObject<RenderBox>(find.byIcon(Icons.menu));
  final origin = icon.localToGlobal(Offset.zero, ancestor: boundary);
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final captured = image!;
  final width = captured.width;
  final bytes = await tester.runAsync(
    () => captured.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  captured.dispose();
  final data = bytes!.buffer.asUint8List();
  var dark = 0;
  var light = 0;
  final left = (origin.dx * 2).round();
  final top = (origin.dy * 2).round();
  final side = (icon.size.shortestSide * 2).round();
  for (var y = top; y < top + side; y++) {
    for (var x = left; x < left + side; x++) {
      final i = (y * width + x) * 4;
      final shade = data[i];
      if (shade < 90) {
        dark++;
      } else {
        light++;
      }
    }
  }
  expect(dark, greaterThan(12));
  expect(light, greaterThan(dark));
}
