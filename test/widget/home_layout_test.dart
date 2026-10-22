import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
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
    expect(find.text('Explore Rentals'), findsOneWidget);
    expect(find.text('Explore rentals'), findsOneWidget);
    expect(find.text('See all >'), findsOneWidget);
    expect(find.text('Why Homizi'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        return widget is Image &&
            _assetName(widget.image) == 'assets/photos/living_05.webp' &&
            widget.alignment == const Alignment(0.35, 0);
      }),
      findsOneWidget,
    );
    expect(_asset('assets/images/home/apartment.webp'), findsWidgets);
    expect(_asset('assets/images/home/house.webp'), findsOneWidget);
    expect(_asset('assets/images/home/roomies.jpg'), findsOneWidget);

    for (final key in const [
      'home-card-profile',
      'home-card-search',
      'home-card-post',
      'home-card-roomie',
    ]) {
      final material = tester.widget<Material>(
        find
            .ancestor(of: find.byKey(Key(key)), matching: find.byType(Material))
            .first,
      );
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
      expect(material.elevation, 0);
    }

    final profile = tester.getTopLeft(find.text('Create Your Profile'));
    final post = tester.getTopLeft(find.text('Post Your Property'));
    final search = tester.getTopLeft(find.text('Search Properties'));
    final roomie = tester.getTopLeft(find.text('Find Your Roomie'));
    expect(post.dx, closeTo(profile.dx, 0.5));
    expect(roomie.dx, closeTo(search.dx, 0.5));
    expect(search.dx, greaterThan(profile.dx + 80));
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
