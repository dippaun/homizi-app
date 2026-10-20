import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/app.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/onboarding/welcome_screen.dart';

void main() {
  testWidgets('welcome sits on white and shows the mark', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HomiziApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump();

    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(HomiziMark), findsWidgets);
    expect(find.text('Agree and continue'), findsOneWidget);
    expect(find.textContaining('Placeholder colors'), findsNothing);

    final context = tester.element(find.byType(WelcomeScreen));
    final theme = Theme.of(context);
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, HomiziColors.white);
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
