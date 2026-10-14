import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/l10n/locale_controller.dart';
import 'package:homizi/features/settings/settings_screen.dart';
import 'package:homizi/l10n/app_localizations.dart';

class _SettingsHost extends ConsumerWidget {
  const _SettingsHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    );
  }
}

void main() {
  testWidgets('the language control switches the scaffolded Hindi labels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: _SettingsHost()));
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Hindi'), findsOneWidget);

    await tester.tap(find.text('Hindi'));
    await tester.pumpAndSettle();

    expect(find.text('भाषा'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('Language'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });
}
