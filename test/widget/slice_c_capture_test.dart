import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/theme/homizi_theme.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/account/demo_account_gateway.dart';
import 'package:homizi/features/account/profile_records.dart';
import 'package:homizi/features/notifications/demo_notification_gateway.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/notification_gateway.dart';
import 'package:homizi/features/notifications/notification_providers.dart';
import 'package:homizi/features/notifications/notifications_screen.dart';
import 'package:homizi/features/profile/profile_hub_screen.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/session_state.dart';
import 'package:homizi/features/support/help_screen.dart';
import 'package:homizi/features/tools/agreement_screen.dart';
import 'package:homizi/features/tools/checklist_screen.dart';
import 'package:homizi/features/tools/deposit_screen.dart';
import 'package:homizi/features/tools/receipt_screen.dart';
import 'package:homizi/features/tools/split_screen.dart';
import 'package:homizi/features/tools/tools_screen.dart';
import 'package:homizi/l10n/app_localizations.dart';

class _ReadySession extends SessionController {
  @override
  SessionState build() {
    return const SessionState(
      phase: SessionPhase.ready,
      contact: 'ananya@example.test',
      role: AccountRole.tenant,
      policyVersion: '2026-10-11-draft',
    );
  }
}

void main() {
  final dir = Platform.environment['HOMIZI_CAPTURE_DIR'];
  if (dir == null || dir.isEmpty) {
    test('slice C capture stays out of CI', () {
      expect(Platform.environment.containsKey('HOMIZI_CAPTURE_DIR'), isFalse);
    });
    return;
  }

  Future<void> shoot(WidgetTester tester, String name) async {
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('shot-frame')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$dir/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget frame(
    String name,
    Widget home, {
    DemoAccountGateway? accounts,
    NotificationGateway? notifications,
  }) {
    return ProviderScope(
      key: Key('scope-$name'),
      overrides: [
        if (accounts != null) ...[
          sessionProvider.overrideWith(_ReadySession.new),
          accountGatewayProvider.overrideWithValue(accounts),
        ],
        if (notifications != null)
          notificationGatewayProvider.overrideWith((ref) => notifications),
      ],
      child: RepaintBoundary(
        key: const Key('shot-frame'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: HomiziTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
  }

  Future<void> reveal(WidgetTester tester, Finder finder) {
    return tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }

  testWidgets('capture profile, tools, and help', (tester) async {
    phone(tester);
    final accounts = DemoAccountGateway();
    await accounts.saveTenantProfile(
      const TenantProfile(
        displayName: 'Ananya Iyer',
        occupation: 'Product designer',
        bio: 'Looking for a quiet furnished room in Koramangala.',
        preferences: TenantPreferences(
          budgetMinInr: 18000,
          budgetMaxInr: 28000,
          localities: ['Koramangala'],
        ),
      ),
    );
    await tester.pumpWidget(
      frame('profile', const ProfileHubScreen(), accounts: accounts),
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'profile-hub');
    await reveal(tester, find.byKey(const Key('profile-activity')));
    await shoot(tester, 'profile-activity');

    final gateway = DemoNotificationGateway();
    gateway.seed(
      InboxNotice(
        id: 'notice-chat',
        type: 'message',
        matchId: '88888888-8888-4888-8888-888888888801',
        createdAt: DateTime.utc(2026, 10, 17, 9),
      ),
    );
    gateway.seed(
      InboxNotice(
        id: 'notice-system',
        type: 'deposit_reminder',
        createdAt: DateTime.utc(2026, 10, 17, 10),
      ),
    );
    await tester.pumpWidget(
      frame('inbox', const NotificationsScreen(), notifications: gateway),
    );
    await tester.pumpAndSettle();
    await shoot(tester, 'notifications-categories');

    await tester.pumpWidget(frame('tools', const ToolsScreen()));
    await tester.pumpAndSettle();
    await shoot(tester, 'tools-grid');
    await reveal(tester, find.byKey(const Key('tool-deposit')));
    await shoot(tester, 'tools-grid-rest');

    await tester.pumpWidget(frame('receipt', const ReceiptScreen()));
    await tester.pumpAndSettle();
    await shoot(tester, 'rent-receipt');

    await tester.pumpWidget(frame('split', const SplitScreen()));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('split-calculate')));
    await tester.tap(find.byKey(const Key('split-calculate')));
    await tester.pumpAndSettle();
    await reveal(tester, find.byKey(const Key('split-band')));
    await shoot(tester, 'rent-split');

    await tester.pumpWidget(frame('agreement', const AgreementScreen()));
    await tester.pumpAndSettle();
    await shoot(tester, 'agreement-draft');

    await tester.pumpWidget(frame('checklist', const ChecklistScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await shoot(tester, 'move-in-checklist');

    await tester.pumpWidget(frame('deposit', const DepositScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('deposit-label')),
      'Koramangala 5th Block',
    );
    await tester.enterText(find.byKey(const Key('deposit-paid')), '84000');
    await tester.enterText(find.byKey(const Key('deposit-due')), '2026-12-01');
    await reveal(tester, find.byKey(const Key('deposit-save')));
    await tester.tap(find.byKey(const Key('deposit-save')));
    await tester.pumpAndSettle();
    await reveal(tester, find.textContaining('Refund due ₹'));
    await shoot(tester, 'deposit-tracker');

    await tester.pumpWidget(frame('help', const HelpScreen()));
    await tester.pumpAndSettle();
    await shoot(tester, 'help-guides');
    await tester.tap(find.widgetWithText(Tab, 'Safety'));
    await tester.pumpAndSettle();
    await shoot(tester, 'help-safety');
    await tester.tap(find.widgetWithText(Tab, 'Contact'));
    await tester.pumpAndSettle();
    await shoot(tester, 'help-contact');
  });
}
