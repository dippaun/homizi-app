import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/legal/legal_document.dart';
import 'package:homizi/features/legal/public_legal_pages.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      MaterialApp(theme: HomiziTheme.light(), home: page),
    );
    await tester.pump();
  }

  testWidgets('privacy states Mumbai, analytics opt-out, and Sentry', (
    tester,
  ) async {
    await pumpPage(tester, const PrivacyPolicyPage());
    expect(find.text(LegalDocumentPage.draftBanner), findsOneWidget);
    expect(find.textContaining('Mumbai (ap-south-1)'), findsWidgets);
    expect(find.textContaining('Turn product analytics off'), findsOneWidget);
    expect(
      find.textContaining('Sentry stays off unless the build was compiled'),
      findsWidgets,
    );
    expect(find.textContaining('Aadhaar'), findsOneWidget);
    expect(find.text(RoutePaths.privacy), findsNothing);
  });

  testWidgets('terms, support, and deletion stay marked as drafts', (
    tester,
  ) async {
    await pumpPage(tester, const TermsPage());
    expect(find.text(LegalDocumentPage.draftBanner), findsOneWidget);
    expect(find.textContaining('does not collect money'), findsOneWidget);

    await pumpPage(tester, const SupportSafetyPage());
    expect(find.text(LegalDocumentPage.draftBanner), findsOneWidget);
    expect(find.textContaining('flag icon'), findsOneWidget);
    expect(find.textContaining('Sentry stays off'), findsOneWidget);

    await pumpPage(tester, const DeleteAccountPage());
    expect(find.text(LegalDocumentPage.draftBanner), findsOneWidget);
    expect(find.textContaining('delete_own_account'), findsOneWidget);
    expect(find.textContaining('this device only'), findsOneWidget);
    expect(find.textContaining('does not call Sentry'), findsOneWidget);
  });
}
