import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/settings/settings_screen.dart';
import 'package:homizi/features/support/help_screen.dart';
import 'package:homizi/l10n/app_localizations.dart';

void main() {
  testWidgets('Hindi mode translates help and settings, not only the tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('hi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HelpScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('सहायता'), findsOneWidget);
    expect(find.text('मार्गदर्शिका'), findsOneWidget);
    expect(find.text('How do I delete my account?'), findsNothing);
    expect(find.text('मैं अपना खाता कैसे हटाऊँ?'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('hi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('सेटिंग्स'), findsOneWidget);
    expect(find.text('Settings'), findsNothing);
    expect(find.text('भाषा'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });
}
