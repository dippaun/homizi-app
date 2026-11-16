import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/login_skyline.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';

List<NavigationDestination> _dests() => const [
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.search),
    selectedIcon: Icon(Icons.search),
    label: 'Explore',
  ),
  NavigationDestination(
    icon: Icon(Icons.groups_outlined),
    selectedIcon: Icon(Icons.groups),
    label: 'Roommates',
  ),
  NavigationDestination(
    icon: Icon(Icons.style_outlined),
    selectedIcon: Icon(Icons.style),
    label: 'Swipe',
  ),
  NavigationDestination(
    icon: Icon(Icons.handshake_outlined),
    selectedIcon: Icon(Icons.handshake),
    label: 'Matches',
  ),
];

List<NavigationDestination> _six() => const [
  NavigationDestination(
    icon: Icon(Icons.home_outlined),
    selectedIcon: Icon(Icons.home),
    label: 'Home',
  ),
  NavigationDestination(
    icon: Icon(Icons.search),
    selectedIcon: Icon(Icons.search),
    label: 'Search',
  ),
  NavigationDestination(
    icon: Icon(Icons.low_priority_outlined),
    selectedIcon: Icon(Icons.low_priority),
    label: 'Priorities',
  ),
  NavigationDestination(
    icon: Icon(Icons.groups_outlined),
    selectedIcon: Icon(Icons.groups),
    label: 'Roommate',
  ),
  NavigationDestination(
    icon: Icon(Icons.chat_bubble_outline),
    selectedIcon: Icon(Icons.chat_bubble),
    label: 'Chat',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person),
    label: 'Profile',
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required int selected,
  required ValueChanged<int> onSelect,
  Size size = const Size(390, 844),
  bool reduceMotion = false,
  bool accent = false,
  double bottomInset = 0,
  List<NavigationDestination>? destinations,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(bottom: bottomInset);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: reduceMotion,
        padding: EdgeInsets.only(bottom: bottomInset),
        viewPadding: EdgeInsets.only(bottom: bottomInset),
      ),
      child: MaterialApp(
        home: Material(
          color: HomiziColors.soft,
          child: Column(
            children: [
              const Expanded(child: ColoredBox(color: HomiziColors.soft)),
              GlassyNavigationBar(
                destinations: destinations ?? _dests(),
                selectedIndex: selected,
                accentSelected: accent,
                onDestinationSelected: onSelect,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders five tabs and marks the selected one', (tester) async {
    var tapped = -1;
    await _pump(tester, selected: 0, onSelect: (i) => tapped = i);

    expect(find.byKey(const Key('glassy-nav')), findsOneWidget);
    final bar = tester.widget<GlassyNavigationBar>(
      find.byType(GlassyNavigationBar),
    );
    expect(bar.destinations, hasLength(5));
    expect(bar.selectedIndex, 0);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Explore'), findsWidgets);
    expect(find.text('Matches'), findsWidgets);

    await tester.tap(find.byIcon(Icons.style_outlined));
    await tester.pump();
    expect(tapped, 3);
  });

  testWidgets('docks flush to the bottom at 360, 768 and 1280', (tester) async {
    for (final width in [360.0, 768.0, 1280.0]) {
      await _pump(
        tester,
        selected: 2,
        size: Size(width, 800),
        onSelect: (_) {},
      );
      expect(tester.takeException(), isNull);
      final nav = tester.getRect(find.byKey(const Key('glassy-nav')));
      expect(nav.left, 0);
      expect(nav.right, width);
      expect(nav.bottom, 800);
      expect(nav.height, GlassyNavigationBar.slotHeight(0));
      final item = tester.getRect(find.byKey(const Key('glassy-nav-item-2')));
      final icon = tester.getCenter(find.byIcon(Icons.groups));
      expect(icon.dx, closeTo(item.center.dx, 1));
      expect(
        tester.getCenter(find.byIcon(Icons.search)).dy,
        closeTo(icon.dy, 0.5),
      );
      expect(
        tester.getCenter(find.text('Roommates')).dy,
        closeTo(tester.getCenter(find.text('Explore')).dy, 0.5),
      );
      expect(find.byKey(const Key('glassy-nav-indicator')), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(ClipRRect), findsNothing);
    }
  });

  testWidgets('respects reduced motion when the tab changes', (tester) async {
    final selected = ValueNotifier(0);
    addTearDown(selected.dispose);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
        child: AnimatedBuilder(
          animation: selected,
          builder: (context, _) {
            return MaterialApp(
              home: Material(
                child: Column(
                  children: [
                    const Expanded(child: SizedBox.shrink()),
                    GlassyNavigationBar(
                      destinations: _dests(),
                      selectedIndex: selected.value,
                      onDestinationSelected: (i) => selected.value = i,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    selected.value = 4;
    await tester.pump();
    expect(
      tester
          .widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
          .selectedIndex,
      4,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('exposes semantics labels and 48px tap targets', (tester) async {
    await _pump(tester, selected: 1, onSelect: (_) {});
    final semantics = tester.getSemantics(find.text('Explore').first);
    expect(semantics.label, contains('Explore'));
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isSelected, Tristate.isTrue);
    final explore = tester.getRect(
      find.ancestor(
        of: find.text('Explore').first,
        matching: find.byType(GestureDetector),
      ),
    );
    expect(explore.width, greaterThanOrEqualTo(48));
    expect(explore.height, greaterThanOrEqualTo(48));
  });

  testWidgets('uses no Material InkWell splash behind tabs', (tester) async {
    await _pump(tester, selected: 1, onSelect: (_) {});
    expect(find.byType(InkWell), findsNothing);
    expect(find.byType(InkResponse), findsNothing);
  });

  testWidgets('active tab is filled logo orange and idle ink is quieter', (
    tester,
  ) async {
    await _pump(tester, selected: 0, accent: true, onSelect: (_) {});
    final bar = tester.widget<GlassyNavigationBar>(
      find.byType(GlassyNavigationBar),
    );
    expect(bar.accentSelected, isTrue);

    final active = tester.widget<Text>(find.text('Home').first);
    expect(active.style?.color, HomiziColors.logoOrange);
    expect(active.style?.fontWeight, FontWeight.w700);

    final idle = tester.widget<Text>(find.text('Explore').first);
    expect(
      idle.style?.color,
      HomiziColors.ink.withValues(alpha: GlassyNavigationBar.inactiveOpacity),
    );
    expect(idle.style?.fontWeight, FontWeight.w500);

    final activeIcon = IconTheme.of(tester.element(find.byIcon(Icons.home)));
    final idleIcon = IconTheme.of(tester.element(find.byIcon(Icons.search)));
    expect(activeIcon.color, HomiziColors.logoOrange);
    expect(activeIcon.size, GlassyNavigationBar.iconSize);
    expect(idleIcon.size, activeIcon.size);
    expect(
      idleIcon.color,
      HomiziColors.ink.withValues(alpha: GlassyNavigationBar.inactiveOpacity),
    );

    final item = tester.getRect(find.byKey(const Key('glassy-nav-item-0')));
    expect(
      tester.getCenter(find.byIcon(Icons.home)).dx,
      closeTo(item.center.dx, 1),
    );
    expect(find.byIcon(Icons.home_outlined), findsNothing);
  });

  testWidgets('keeps labels above the home indicator', (tester) async {
    const inset = 34.0;
    await _pump(tester, selected: 0, bottomInset: inset, onSelect: (_) {});
    final nav = tester.getRect(find.byKey(const Key('glassy-nav')));
    expect(nav.left, 0);
    expect(nav.right, 390);
    expect(nav.bottom, 844);
    expect(nav.height, GlassyNavigationBar.slotHeight(inset));
    final label = tester.getRect(find.text('Home').first);
    expect(label.bottom, lessThanOrEqualTo(844 - inset + 0.5));
    final item = tester.getRect(find.byKey(const Key('glassy-nav-item-0')));
    expect(item.height, greaterThanOrEqualTo(48));
    expect(item.bottom, closeTo(844, 0.5));
  });

  testWidgets('paints the sign-in skyline under the tabs', (tester) async {
    await _pump(tester, selected: 0, onSelect: (_) {});
    final skyline = find.byKey(const Key('nav-skyline'));
    expect(skyline, findsOneWidget);
    final opacity = tester.widget<Opacity>(skyline);
    expect(opacity.opacity, lessThanOrEqualTo(0.45));
    expect(opacity.opacity, greaterThan(0));
    expect(
      find.ancestor(of: skyline, matching: find.byType(IgnorePointer)),
      findsWidgets,
    );
    final paint = tester.widget<CustomPaint>(
      find.descendant(of: skyline, matching: find.byType(CustomPaint)),
    );
    expect(paint.painter, isA<CitySkylinePainter>());
    expect((paint.painter! as CitySkylinePainter).reveal, 1);

    final scrim = tester.widget<DecoratedBox>(
      find.byKey(const Key('nav-skyline-scrim')),
    );
    final gradient =
        (scrim.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.colors.first.a, greaterThanOrEqualTo(0.7));

    final label = tester.widget<Text>(find.text('Home').first);
    expect(label.style?.color, HomiziColors.logoOrange);
  });

  testWidgets('six tabs stay tappable on a 320-wide phone', (tester) async {
    await _pump(
      tester,
      selected: 2,
      size: const Size(320, 700),
      destinations: _six(),
      onSelect: (_) {},
    );
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 6; i++) {
      final item = tester.getRect(find.byKey(Key('glassy-nav-item-$i')));
      expect(item.width, greaterThanOrEqualTo(48));
      expect(item.height, greaterThanOrEqualTo(48));
    }
    final active = tester.widget<Text>(find.text('Priorities').first);
    expect(active.style?.color, HomiziColors.logoOrange);
    expect(active.style?.fontWeight, FontWeight.w700);
  });

  testWidgets('hover washes the item without shifting its icon', (
    tester,
  ) async {
    await _pump(tester, selected: 0, onSelect: (_) {});
    final before = tester.getCenter(find.byIcon(Icons.search));
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: before);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const Key('glassy-nav-hover')), findsOneWidget);
    final after = tester.getCenter(find.byIcon(Icons.search));
    expect(after.dx, closeTo(before.dx, 0.5));
    expect(after.dy, closeTo(before.dy, 0.5));
    final hover = tester.getRect(find.byKey(const Key('glassy-nav-hover')));
    final item = tester.getRect(find.byKey(const Key('glassy-nav-item-1')));
    expect(hover.center.dx, closeTo(item.center.dx, 1));
    expect(hover.center.dy, closeTo(item.center.dy, 1));
    await gesture.removePointer();
  });
}
