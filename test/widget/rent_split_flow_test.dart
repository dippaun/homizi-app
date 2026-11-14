import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/tools/domain/smart_split.dart';
import 'package:homizi/features/tools/rent_split/rent_split_repository.dart';
import 'package:homizi/features/tools/split_screen.dart';

class _Remote implements RentSplitRemote {
  _Remote(this.ok);

  final bool ok;
  final saved = <SavedRentSplit>[];

  @override
  Future<bool> save(SavedRentSplit split) async {
    saved.add(split);
    return ok;
  }
}

void main() {
  late MemoryRentSplitStore store;

  Future<_Remote> pump(
    WidgetTester tester, {
    bool remoteOk = false,
    List<String> roommates = const [],
  }) async {
    store = MemoryRentSplitStore();
    final remote = _Remote(remoteOk);
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          rentSplitRepositoryProvider.overrideWithValue(
            RentSplitRepository(local: store, remote: remote),
          ),
        ],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: SplitScreen(roommates: roommates),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return remote;
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final finder = find.byKey(Key(key));
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('setup → rooms → smart result → agree → finalized → demo pay', (
    tester,
  ) async {
    final remote = await pump(tester, roommates: const ['Amit', 'Rahul']);
    expect(find.text('Set up rent split'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byKey(const Key('split-people')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('split-people'))).data,
      '3',
    );

    await tap(tester, 'split-start');
    expect(find.text('Add room & occupancy details'), findsOneWidget);
    expect(find.text('Room 1 (Master)'), findsOneWidget);
    expect(find.text('Larger room + Attached bathroom'), findsOneWidget);
    expect(find.text('Standard room + Common bathroom'), findsNWidgets(2));

    await tap(tester, 'split-calculate');
    expect(find.text('Rent split result'), findsOneWidget);
    expect(find.text('₹30,000 / month'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('split-amount-0'))).data,
      '₹13,500',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('split-amount-1'))).data,
      '₹8,250',
    );
    expect(find.text('Amit'), findsOneWidget);
    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('Total: ₹30,000'), findsOneWidget);
    expect(find.byKey(const Key('split-how')), findsOneWidget);

    await tap(tester, 'split-mode-equal');
    expect(
      tester.widget<Text>(find.byKey(const Key('split-amount-0'))).data,
      '₹10,000',
    );
    await tap(tester, 'split-mode-smart');

    await tap(tester, 'split-review');
    expect(find.text('Review & agree'), findsWidgets);
    expect(find.textContaining('Waiting for 3 to agree'), findsOneWidget);
    await tap(tester, 'split-agree-0');
    await tap(tester, 'split-agree-1');
    await tap(tester, 'split-agree-2');
    await tap(tester, 'split-finalize');

    expect(find.byKey(const Key('split-done')), findsOneWidget);
    expect(find.text('Saved on this device.'), findsOneWidget);
    expect(store.splits, hasLength(1));
    expect(store.splits.single.agreed, ['You', 'Amit', 'Rahul']);
    expect(remote.saved, hasLength(1));

    await tap(tester, 'split-pay');
    expect(find.byKey(const Key('split-paid')), findsOneWidget);
    expect(find.textContaining('No real money moved'), findsOneWidget);
  });

  testWidgets('server copy, when the table exists, is reported', (
    tester,
  ) async {
    await pump(tester, remoteOk: true);
    await tap(tester, 'split-start');
    await tap(tester, 'split-calculate');
    await tap(tester, 'split-review');
    for (var i = 0; i < 3; i++) {
      await tap(tester, 'split-agree-$i');
    }
    await tap(tester, 'split-finalize');
    expect(find.text('Saved to your HOMIZI account.'), findsOneWidget);
    await tap(tester, 'split-new');
    expect(find.text('Set up rent split'), findsOneWidget);
    expect(find.text('Your saved splits'), findsOneWidget);
  });

  testWidgets('a room edit changes the weights', (tester) async {
    await pump(tester);
    await tap(tester, 'split-start');
    await tap(tester, 'split-room-1');
    await tap(tester, 'split-bath');
    await tap(tester, 'split-room-save');
    expect(find.text('Standard room + Attached bathroom'), findsOneWidget);
    await tap(tester, 'split-calculate');
    // 90 : 70 : 55 of ₹30,000.
    expect(
      tester.widget<Text>(find.byKey(const Key('split-amount-1'))).data,
      '₹9,768',
    );
  });

  testWidgets('occupancy and custom split validation', (tester) async {
    await pump(tester);
    await tap(tester, 'split-start');
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('split-occupancy-0')),
        matching: find.byType(DropdownButtonFormField<int>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 people').last);
    await tester.pumpAndSettle();
    expect(find.text('You · Roommate 4'), findsOneWidget);
    await tap(tester, 'split-calculate');
    expect(find.byKey(const Key('split-amount-3')), findsOneWidget);

    await tap(tester, 'split-mode-custom');
    await tester.enterText(find.byKey(const Key('split-custom-0')), '1000');
    await tester.pumpAndSettle();
    expect(find.textContaining('short of the rent'), findsOneWidget);
    final review = tester.widget<InkWell>(
      find.byKey(const Key('split-review')),
    );
    expect(review.onTap, isNull);
  });

  testWidgets('bad input stays on setup with a message; back walks steps', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byKey(const Key('split-rent')), '');
    await tap(tester, 'split-start');
    expect(find.byKey(const Key('split-note')), findsOneWidget);
    expect(find.text('Set up rent split'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('split-rent')), '45000');
    await tap(tester, 'split-bhk-2 BHK');
    await tap(tester, 'split-start');
    expect(find.text('Room 2'), findsOneWidget);
    expect(find.text('Room 3'), findsNothing);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Set up rent split'), findsOneWidget);
  });
}
