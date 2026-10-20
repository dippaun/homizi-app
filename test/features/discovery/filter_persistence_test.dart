import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/discovery/feed_controller.dart';
import 'package:homizi/features/discovery/filter_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final disk = <String, Object>{};

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    disk.clear();
    _mock(androidFilterPrefsSetString, (Object? message) async {
      final args = _args(message);
      disk[args[0]! as String] = args[1]! as String;
      return <Object?>[true];
    });
    _mock(androidFilterPrefsRemove, (Object? message) async {
      final args = _args(message);
      disk.remove(args[0]! as String);
      return <Object?>[true];
    });
    _mock(androidFilterPrefsGetAll, (Object? message) async {
      final args = _args(message);
      final prefix = args[0]! as String;
      final allow = args[1] is List<dynamic>
          ? (args[1]! as List<dynamic>).map((item) => '$item').toSet()
          : null;
      return <Object?>[
        <String, Object>{
          for (final entry in disk.entries)
            if (entry.key.startsWith(prefix) &&
                (allow == null || allow.contains(entry.key)))
              entry.key: entry.value,
        },
      ];
    });
  });

  tearDown(() {
    _mock(androidFilterPrefsSetString, null);
    _mock(androidFilterPrefsRemove, null);
    _mock(androidFilterPrefsGetAll, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'a search query survives a new process and a blank query clears it',
    () async {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      await first.read(listingFilterProvider.notifier).persistence;
      first.read(listingFilterProvider.notifier).setQuery('Baner');
      await first.read(listingFilterProvider.notifier).persistence;

      final second = ProviderContainer();
      addTearDown(second.dispose);
      await second.read(listingFilterProvider.notifier).persistence;
      expect(second.read(listingFilterProvider).query, 'Baner');
      expect(second.read(listingFilterProvider).city, isNull);

      second.read(listingFilterProvider.notifier).setQuery('   ');
      await second.read(listingFilterProvider.notifier).persistence;
      expect(disk.containsKey(appliedFiltersPreferenceKey), isFalse);

      final third = ProviderContainer();
      addTearDown(third.dispose);
      await third.read(listingFilterProvider.notifier).persistence;
      expect(third.read(listingFilterProvider).isDefault, isTrue);
    },
  );

  test('a corrupt device copy does not replace the default filters', () async {
    disk[appliedFiltersPreferenceKey] = '{';
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(listingFilterProvider.notifier).persistence;
    expect(container.read(listingFilterProvider).isDefault, isTrue);
  });

  testWidgets(
    'applied filters survive leaving the screen and a new process, and clear wipes them',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        final first = ProviderContainer();
        addTearDown(first.dispose);
        final router = _router();
        addTearDown(router.dispose);
        await _pump(tester, first, router);
        unawaited(router.push('/filters'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('filter-locality')),
          'Kothrud',
        );
        await tester.pump();
        await tester.ensureVisible(find.widgetWithText(FilterChip, 'Pune'));
        await tester.tap(find.widgetWithText(FilterChip, 'Pune'));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('filter-show-homes')));
        await tester.tap(find.byKey(const Key('filter-show-homes')));
        await tester.pumpAndSettle();

        expect(find.text('home'), findsOneWidget);
        expect(first.read(listingFilterProvider).city, 'Pune');
        expect(first.read(listingFilterProvider).locality, 'Kothrud');
        await first.read(listingFilterProvider.notifier).persistence;

        final saved = disk[appliedFiltersPreferenceKey]! as String;
        expect(saved.contains('Pune'), isTrue);
        expect(saved.contains('Kothrud'), isTrue);
        expect(saved.contains('landmark'), isFalse);
        expect(saved.contains('phone'), isFalse);
        expect(saved.contains('email'), isFalse);

        final second = ProviderContainer();
        addTearDown(second.dispose);
        await second.read(listingFilterProvider.notifier).persistence;
        expect(second.read(listingFilterProvider).city, 'Pune');
        expect(second.read(listingFilterProvider).locality, 'Kothrud');
        expect(
          second.read(listingFilterProvider).signature,
          first.read(listingFilterProvider).signature,
        );

        final again = _router();
        addTearDown(again.dispose);
        await _pump(tester, second, again);
        unawaited(again.push('/filters'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('filter-locality')))
              .controller!
              .text,
          'Kothrud',
        );
        expect(
          tester
              .widget<FilterChip>(find.widgetWithText(FilterChip, 'Pune'))
              .selected,
          isTrue,
        );

        await tester.ensureVisible(find.byKey(const Key('filter-reset')));
        await tester.tap(find.byKey(const Key('filter-reset')));
        await tester.pump();
        await second.read(listingFilterProvider.notifier).persistence;

        expect(second.read(listingFilterProvider).isDefault, isTrue);
        expect(disk.containsKey(appliedFiltersPreferenceKey), isFalse);
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('filter-locality')))
              .controller!
              .text,
          isEmpty,
        );

        final third = ProviderContainer();
        addTearDown(third.dispose);
        await third.read(listingFilterProvider.notifier).persistence;
        expect(third.read(listingFilterProvider).isDefault, isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

void _mock(
  BasicMessageChannel<Object?> channel,
  Future<Object?> Function(Object? message)? handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockDecodedMessageHandler<Object?>(channel, handler);
}

List<Object?> _args(Object? message) {
  if (message is Iterable<Object?>) {
    return List<Object?>.from(message);
  }
  if (message is Iterable<dynamic>) {
    return List<Object?>.from(message);
  }
  throw StateError('Expected a preferences argument list.');
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/filters',
        builder: (context, state) => const FilterScreen(),
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router,
) {
  return tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: HomiziTheme.light(),
        routerConfig: router,
      ),
    ),
  );
}
