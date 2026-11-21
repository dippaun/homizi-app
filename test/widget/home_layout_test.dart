import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
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

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

String? _assetName(ImageProvider<Object> provider) {
  if (provider is AssetImage) {
    return provider.assetName;
  }
  if (provider is ResizeImage) {
    final nested = provider.imageProvider;
    if (nested is AssetImage) {
      return nested.assetName;
    }
  }
  return null;
}

Finder _asset(String name) {
  return find.byWidgetPredicate((widget) {
    return widget is Image && _assetName(widget.image) == name;
  });
}

void main() {
  testWidgets('the home hero, tiles, and rentals stay borderless', (
    tester,
  ) async {
    await _pump(tester, const Size(390, 1400));

    expect(find.text('Find a place.'), findsOneWidget);
    expect(find.text('Find your people.'), findsOneWidget);
    expect(find.text('Rent smarter, live better.'), findsOneWidget);
    expect(find.text('Explore rentals'), findsOneWidget);
    expect(find.text('See all >'), findsOneWidget);
    expect(find.text('Why Homizi'), findsNothing);
    expect(find.byKey(const Key('home-swipe-card')), findsNothing);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is Image &&
            _assetName(widget.image) == 'assets/images/real/living_b.webp' &&
            widget.alignment == const Alignment(0.35, 0);
      }),
      findsOneWidget,
    );
    expect(_asset('assets/images/real/apartment.webp'), findsWidgets);
    expect(_asset('assets/images/real/exterior.webp'), findsOneWidget);
    expect(_asset('assets/images/real/bedroom.webp'), findsOneWidget);
    expect(_asset('assets/images/real/people.webp'), findsOneWidget);

    expect(find.byKey(const Key('home-card-profile')), findsNothing);
    expect(find.byKey(const Key('home-custom-section')), findsOneWidget);
    const keys = [
      'home-card-post',
      'home-card-post-room',
      'home-card-roomie',
      'home-card-search',
    ];
    Size? tile;
    for (final key in keys) {
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.byKey(Key(key)), matching: find.byType(Material))
            .first,
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
      expect(material.elevation, 0);
      expect(material.color, HomiziColors.white);
      final size = tester.getSize(find.byKey(Key(key)));
      tile ??= size;
      expect(size.width, closeTo(tile.width, 0.5));
      expect(size.height, closeTo(tile.height, 0.5));
    }

    final post = tester.getTopLeft(find.byKey(const Key('home-card-post')));
    final room = tester.getTopLeft(
      find.byKey(const Key('home-card-post-room')),
    );
    final roomie = tester.getTopLeft(find.byKey(const Key('home-card-roomie')));
    final search = tester.getTopLeft(find.byKey(const Key('home-card-search')));
    expect(room.dy, closeTo(post.dy, 0.5));
    expect(room.dx, greaterThan(post.dx + 80));
    expect(roomie.dy, greaterThan(post.dy + 40));
    expect(roomie.dx, closeTo(post.dx, 0.5));
    expect(search.dy, closeTo(roomie.dy, 0.5));
    expect(search.dx, closeTo(room.dx, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a wide window centers the home column', (tester) async {
    await _pump(tester, const Size(1280, 900));
    expect(tester.takeException(), isNull);
    final screen = tester.getSize(find.byKey(const Key('home-screen')));
    expect(screen.width, lessThanOrEqualTo(480));
    expect(
      tester.getTopLeft(find.byKey(const Key('home-screen'))).dx,
      greaterThan(300),
    );
  });
}
