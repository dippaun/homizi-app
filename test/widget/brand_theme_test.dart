import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

void main() {
  testWidgets('welcome sits on white and shows the mark', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HomiziApp()));
    await tester.pump();
    await tester.tap(find.byKey(const Key('splash-sign-in')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-screen')), findsOneWidget);
    expect(find.text('HOMIZI'), findsWidgets);
    expect(find.textContaining('Placeholder colors'), findsNothing);

    final context = tester.element(find.byKey(const Key('home-screen')));
    final theme = Theme.of(context);
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, HomiziColors.soft);
    expect(theme.colorScheme.surface, HomiziColors.white);
    expect(theme.colorScheme.primary, HomiziColors.accent);
    expect(theme.colorScheme.onPrimary, HomiziColors.ink);
    expect(theme.appBarTheme.toolbarHeight, 64);
    expect(theme.navigationBarTheme.height, 80);
    expect(
      theme.textTheme.headlineSmall?.fontFamily,
      contains('PlusJakartaSans'),
    );
    expect(theme.textTheme.bodyMedium?.fontFamily, contains('Inter'));
  });
}
