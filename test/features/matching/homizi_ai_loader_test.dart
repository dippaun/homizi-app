import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/matching/homizi_ai_loader.dart';

void main() {
  test('a fast load still waits out the minimum, a slow one does not', () {
    final start = DateTime.utc(2026, 11, 24, 12);
    expect(
      matchLoaderHoldLeft(start, start.add(const Duration(milliseconds: 200))),
      const Duration(milliseconds: 1000),
    );
    expect(
      matchLoaderHoldLeft(start, start.add(const Duration(milliseconds: 1200))),
      Duration.zero,
    );
    expect(
      matchLoaderHoldLeft(start, start.add(const Duration(seconds: 3))),
      Duration.zero,
    );
  });

  testWidgets('the homes loader paints the wordmark and the match line', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: HomiziAiMatchLoader(kind: HomiziAiKind.homes)),
    );
    await tester.pump();
    expect(find.byKey(const Key('homizi-ai-loader')), findsOneWidget);
    expect(find.textContaining('HOMIZI'), findsOneWidget);
    expect(
      find.text('Homizi AI is finding your perfect match…'),
      findsOneWidget,
    );
    expect(find.textContaining('Checking budget'), findsOneWidget);
  });
}
