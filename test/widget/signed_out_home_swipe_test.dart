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
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/host/host_options_screen.dart';
import 'package:homizi/features/post_property/post_property_chooser_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
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

Future<GoRouter> _pump(WidgetTester tester) async {
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
  return GoRouter.of(tester.element(find.byKey(const Key('home-screen'))));
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('signed-out home shows the usual sections without search', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.text('Find a place.'), findsOneWidget);
    expect(find.text('Find your people.'), findsOneWidget);
    expect(find.text('Create Your Profile'), findsWidgets);
    expect(find.text('Post Your Property'), findsOneWidget);
    expect(find.text('Find Your Roomie'), findsOneWidget);
    expect(find.text('Explore rentals'), findsOneWidget);
    expect(find.byKey(const Key('home-see-all')), findsOneWidget);
    expect(find.byKey(const Key('home-flats-card')), findsOneWidget);
    expect(find.byType(GlassyNavigationBar), findsOneWidget);
    expect(find.text('Search Properties'), findsNothing);
    expect(find.text('Priorities'), findsNothing);
    expect(find.text('Set My Priorities'), findsNothing);
    expect(find.textContaining('% Match'), findsNothing);
    expect(find.byKey(const Key('home-card-search')), findsNothing);
    expect(find.byKey(const Key('home-guest-flats')), findsNothing);
    expect(find.text('Available flats'), findsNothing);
    expect(find.byKey(const Key('match-skip')), findsNothing);
    expect(find.byKey(const Key('match-interested')), findsNothing);
    await _shoot(tester, '01-signed-out-home');
  });

  testWidgets('signed-out flats deck swipes and asks for sign-in', (
    tester,
  ) async {
    final router = await _pump(tester);
    router.go(RoutePaths.flats);
    await _until(tester, find.byKey(const Key('flats-swipe-screen')));

    expect(find.byKey(const Key('flats-swipe-card')), findsOneWidget);
    expect(find.byKey(const Key('flats-swipe-hint')), findsOneWidget);
    expect(find.text('← Skip  ↑ Later  Interested →'), findsOneWidget);
    expect(find.textContaining('% Match'), findsNothing);
    expect(
      find.text('Why this is a great match for you (Top 5)'),
      findsNothing,
    );
    expect(find.byKey(const Key('match-skip')), findsNothing);
    expect(find.byKey(const Key('match-interested')), findsNothing);
    expect(find.text("I'm Interested"), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
    await _until(tester, find.text('Nearby Places'));
    expect(find.text('Nearby Places'), findsOneWidget);
    await _shoot(tester, '02-flats-swipe');

    final details = find.descendant(
      of: find.byKey(const Key('flats-swipe-card')),
      matching: find.byType(ListView),
    );
    final right = await tester.startGesture(
      tester.getTopLeft(details) + const Offset(48, 36),
    );
    await right.moveBy(const Offset(180, 0));
    await tester.pump();
    expect(
      find.byKey(const Key('flats-swipe-stamp-interested')),
      findsOneWidget,
    );
    await right.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign-in-prompt')), findsOneWidget);
    expect(find.byKey(const Key('flats-swipe-card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('sign-in-prompt-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('contact-field')), findsOneWidget);
    expect(
      GoRouter.of(
        tester.element(find.byKey(const Key('contact-field'))),
      ).state.uri.queryParameters['next'],
      RoutePaths.flats,
    );

    router.go(RoutePaths.flats);
    await _until(tester, find.byKey(const Key('flats-swipe-card')));
    await tester.tap(find.byKey(const Key('property-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign-in-prompt')), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('property-card-contact')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign-in-prompt')), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    final photos = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'property-photos-',
          ),
    );
    final later = await tester.startGesture(tester.getCenter(photos.first));
    await later.moveBy(const Offset(0, -180));
    await tester.pump();
    expect(find.byKey(const Key('flats-swipe-stamp-later')), findsOneWidget);
    await later.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byKey(const Key('sign-in-prompt')), findsOneWidget);
  });

  testWidgets('signed-out Post Property opens the chooser', (tester) async {
    final router = await _pump(tester);
    await tester.ensureVisible(find.byKey(const Key('home-card-post')));
    await tester.tap(find.byKey(const Key('home-card-post')));
    await _until(tester, find.byKey(const Key('post-property-chooser')));

    expect(find.byKey(const Key('post-property-chooser')), findsOneWidget);
    expect(find.text('Post as Owner'), findsOneWidget);
    expect(find.text('Post as Property Partner'), findsOneWidget);
    expect(find.text('Post as Shared Room / Full House'), findsOneWidget);
    expect(find.byKey(const Key('sign-in-prompt')), findsNothing);
    expect(find.byKey(const Key('listing-start')), findsNothing);
    await _shoot(tester, '03-post-chooser');

    router.go(RoutePaths.more);
    await _until(tester, find.byKey(const Key('more-post')));
    await tester.tap(find.byKey(const Key('more-post')));
    await _until(tester, find.byKey(const Key('post-property-chooser')));
    expect(find.byKey(const Key('post-property-chooser')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-prompt')), findsNothing);
  });

  testWidgets('host journey Post property opens the chooser while signed out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: RoutePaths.hostOptions,
      routes: [
        GoRoute(
          path: RoutePaths.hostOptions,
          builder: (context, state) => const HostOptionsScreen(),
        ),
        GoRoute(
          path: RoutePaths.postProperty,
          builder: (context, state) => const PostPropertyChooserScreen(),
        ),
        GoRoute(
          path: RoutePaths.login,
          builder: (context, state) => const Scaffold(body: Text('Sign in')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_SignedOut.new)],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const Key('host-post-property')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('post-property-chooser')), findsOneWidget);
    expect(find.byKey(const Key('sign-in-prompt')), findsNothing);
    expect(find.text('Sign in'), findsNothing);
  });
}

Future<void> _shoot(WidgetTester tester, String name) async {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    return;
  }
  await tester.runAsync(_loadCaptureFonts);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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
}
