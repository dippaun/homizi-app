import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
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

Future<void> _pump(
  WidgetTester tester, {
  required int selected,
  required ValueChanged<int> onSelect,
  Size size = const Size(390, 844),
  bool reduceMotion = false,
  bool accent = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: size,
        disableAnimations: reduceMotion,
      ),
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: HomiziColors.soft,
          extendBody: true,
          body: const ColoredBox(color: HomiziColors.soft),
          bottomNavigationBar: GlassyNavigationBar(
            destinations: _dests(),
            selectedIndex: selected,
            accentSelected: accent,
            onDestinationSelected: onSelect,
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

    await tester.tap(find.text('Swipe').first);
    await tester.pump();
    expect(tapped, 3);
  });

  testWidgets('hump slides across 360, 768 and 1280 widths', (tester) async {
    for (final width in [360.0, 768.0, 1280.0]) {
      var selected = 2;
      await _pump(
        tester,
        selected: selected,
        size: Size(width, 800),
        onSelect: (i) => selected = i,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(GlassyNavigationBar), findsOneWidget);
      expect(
        tester.widget<GlassyNavigationBar>(find.byType(GlassyNavigationBar))
            .selectedIndex,
        2,
      );
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
              home: Scaffold(
                bottomNavigationBar: GlassyNavigationBar(
                  destinations: _dests(),
                  selectedIndex: selected.value,
                  onDestinationSelected: (i) => selected.value = i,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
    selected.value = 4;
    await tester.pump(); // one frame, no animation frames needed
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
    expect(semantics.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
    final explore = tester.getRect(find.ancestor(
      of: find.text('Explore').first,
      matching: find.byType(InkWell),
    ));
    expect(explore.width, greaterThanOrEqualTo(48));
    expect(explore.height, greaterThanOrEqualTo(48));
  });

  testWidgets('active chrome uses brand deep orange glow path', (tester) async {
    await _pump(tester, selected: 0, accent: true, onSelect: (_) {});
    expect(find.byType(CustomPaint), findsWidgets);
    final bar = tester.widget<GlassyNavigationBar>(
      find.byType(GlassyNavigationBar),
    );
    expect(bar.accentSelected, isTrue);
  });
}
