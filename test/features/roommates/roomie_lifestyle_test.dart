import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/roommates/domain/roommate_profile_row.dart';
import 'package:homizi/features/roommates/roomie/roomie.dart';
import 'package:homizi/features/roommates/roomie/roomie_logic.dart';
import 'package:homizi/features/roommates/roomie/roomie_models.dart';
import 'package:homizi/features/roommates/roomie/roomie_store.dart';

RoomieBrief _brief({
  String food = 'vegetarian',
  String smoking = 'no',
  String drinking = 'no',
  String guests = 'rarely',
  String cooking = 'cook_myself',
  String lifestyleNote = '',
}) {
  return RoomieBrief(
    budgetMinInr: 18000,
    budgetMaxInr: 32000,
    city: 'Bengaluru',
    localities: const ['Koramangala', 'Indiranagar'],
    moveIn: DateTime.utc(2026, 12),
    occupation: 'Product designer',
    food: food,
    smoking: smoking,
    drinking: drinking,
    guests: guests,
    cooking: cooking,
    genderPreference: 'any',
    lifestyleNote: lifestyleNote,
  );
}

void main() {
  test('lifestyle answers change the percent and fit the profile row', () {
    expect(canSeeRoomieLifestyle(isVerified: true, isPremium: true), isTrue);
    expect(canSeeRoomieLifestyle(isVerified: true, isPremium: false), isFalse);
    expect(canSeeRoomieLifestyle(isVerified: false, isPremium: true), isFalse);

    final same = roomieFit(_brief(), _brief());
    final apart = roomieFit(
      _brief(),
      _brief(
        food: 'non_vegetarian',
        smoking: 'yes',
        drinking: 'yes',
        guests: 'frequently',
        cooking: 'prefer_not',
        lifestyleNote: 'Late parties every weekend',
      ),
    );
    expect(same.lifestylePoints, RoomieFit.lifestyleMax);
    expect(apart.lifestylePoints, lessThan(same.lifestylePoints));
    expect(apart.percent, lessThan(same.percent));

    final hidden = roomieFitForViewer(same, canSeeLifestyle: false);
    expect(hidden.percent, same.percent);
    expect(hidden.lifestyleDetail, roomieLifestyleGate);

    final note = List.filled(350, 'a').join();
    final row = {
      ...roommateProfileRow(_brief(lifestyleNote: note).toRequirementDraft()),
      ...roomieLifestyleColumns(
        _brief(
          food: 'undisclosed',
          smoking: 'undisclosed',
          lifestyleNote: note,
        ),
      ),
    };
    expect(row['lifestyle_food'], 'undisclosed');
    expect(row['lifestyle_smoking'], 'undisclosed');
    expect(row['lifestyle_drinking'], 'no');
    expect(row['lifestyle_guests'], 'rarely');
    expect(row['lifestyle_cooking'], 'cook_myself');
    expect((row['lifestyle_note'] as String).length, 300);
    expect(row['food'], isNull);
    expect(row['smoking'], isNull);
    expect(row['cooking'], 'often');
    expect(row['guests'], 'rare');
  });

  testWidgets('unverified viewers do not see lifestyle details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final router = GoRouter(
      initialLocation: RoutePaths.roomiePerson('mira'),
      routes: roomieRoutes(),
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomieProvider.overrideWith(_ReadyBrief.new),
          roomieViewerProvider.overrideWithValue(
            const RoomieViewer(isVerified: false, isPremium: true),
          ),
        ],
        child: MaterialApp.router(
          theme: HomiziTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(roomieLifestyleGate), findsWidgets);
    expect(find.textContaining('Quiet kitchen'), findsNothing);
    expect(find.textContaining('Vegetarian'), findsNothing);
    expect(find.textContaining('%'), findsWidgets);
    expect(find.byType(BackButton), findsOneWidget);
  });
}

class _ReadyBrief extends RoomieController {
  @override
  RoomieState build() => RoomieState(brief: _brief());
}
