import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapSearch(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Finder searchOption(String label) => find.byKey(Key('search-option-$label'));

Future<void> searchContinue(WidgetTester tester) async {
  await tapSearch(tester, find.byKey(const Key('search-continue')));
  await tester.pump(const Duration(milliseconds: 50));
}

/// Answers every required question and stops on Confirm.
/// [onLocation] runs on step 2 before Continue, for tests that type a place.
Future<void> completeSearchWizard(
  WidgetTester tester, {
  String place = 'Vastrapur, Ahmedabad',
  Future<void> Function()? onLocation,
}) async {
  const any = 'Anything suitable to my budget';
  await tapSearch(tester, searchOption(any).first);
  await tapSearch(tester, searchOption(any).last);
  await searchContinue(tester);

  if (onLocation != null) {
    await onLocation();
  } else if (place.isNotEmpty) {
    await tester.enterText(find.byKey(const Key('search-area-field')), place);
    await tester.pump();
  }
  await tapSearch(tester, searchOption('Flexible'));
  await searchContinue(tester);

  await tapSearch(tester, searchOption('Any (suitable to my budget)'));
  await searchContinue(tester);

  await tapSearch(tester, searchOption(any));
  await tapSearch(tester, searchOption('No Preference').first);
  await tapSearch(tester, searchOption('No Preference').last);
  await searchContinue(tester);
}
