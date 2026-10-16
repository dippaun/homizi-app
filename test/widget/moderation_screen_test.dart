import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/moderation/domain/moderation_queue.dart';
import 'package:homizi/features/moderation/moderation_gateway.dart';
import 'package:homizi/features/moderation/moderation_providers.dart';
import 'package:homizi/features/moderation/moderation_screen.dart';

class _StaffQueue implements ModerationGateway {
  String? hiddenId;
  String? suspendedId;
  String? reviewedStatus;

  @override
  Future<bool> isStaff() async => true;

  @override
  Future<List<ModerationReport>> listReports() async {
    return const [
      ModerationReport(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
        targetType: 'property',
        targetId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
        reason: 'fake_listing',
        status: 'open',
      ),
      ModerationReport(
        id: 'cccccccc-cccc-4ccc-8ccc-ccccccccccc3',
        targetType: 'user',
        targetId: 'dddddddd-dddd-4ddd-8ddd-ddddddddddd4',
        reason: 'harassment',
        status: 'reviewing',
      ),
    ];
  }

  @override
  Future<ModerationResult> reviewReport(String reportId, String status) async {
    reviewedStatus = status;
    return const ModerationResult(message: 'Report updated.');
  }

  @override
  Future<ModerationResult> hideListing(String propertyId) async {
    hiddenId = propertyId;
    return const ModerationResult(
      message: 'The listing is hidden from the feed.',
    );
  }

  @override
  Future<ModerationResult> suspendUser(String userId) async {
    suspendedId = userId;
    return const ModerationResult(message: 'The account is suspended.');
  }
}

void main() {
  testWidgets('staff can hide a listing and suspend an account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gateway = _StaffQueue();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [moderationGatewayProvider.overrideWith((ref) => gateway)],
        child: const MaterialApp(home: ModerationScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('No phone number or email'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.text('Listing · Fake listing'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const Key('hide-listing-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(gateway.hiddenId, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2');
    expect(find.textContaining('hidden from the feed'), findsOneWidget);

    await tester.tap(
      find.byKey(
        const Key('suspend-user-cccccccc-cccc-4ccc-8ccc-ccccccccccc3'),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(gateway.suspendedId, 'dddddddd-dddd-4ddd-8ddd-ddddddddddd4');
    expect(find.textContaining('suspended'), findsWidgets);
    expect(find.textContaining('@'), findsNothing);
  });
}
