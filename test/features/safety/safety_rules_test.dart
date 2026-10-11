import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/safety/demo_safety_gateway.dart';
import 'package:homizi/features/safety/domain/safety_rules.dart';
import 'package:homizi/features/safety/safety_gateway.dart';

void main() {
  const matchId = '88888888-8888-4888-8888-888888888801';

  test('a report insert uses only the granted columns', () {
    final row = reportInsertRow(
      reporterId: matchId,
      targetType: 'listing',
      targetId: 'lst_koramangala',
      reason: 'spam',
      details: 'The photos do not match the home.',
    );
    expect(row.keys.toSet(), {
      'reporter_id',
      'target_type',
      'target_id',
      'reason',
      'details',
    });
    expect(row['target_type'], 'property');
    expect(row.containsKey('status'), isFalse);
    expect(row.containsKey('phone'), isFalse);
  });

  test('contact text and a phone id are refused', () {
    expect(
      () => reportInsertRow(
        reporterId: matchId,
        targetType: 'user',
        targetId: matchId,
        reason: 'other',
        details: 'call 9876543210',
      ),
      throwsArgumentError,
    );
    expect(
      () => blockInsertRow(blockerId: '9876543210', blockedUserId: matchId),
      throwsArgumentError,
    );
    expect(safetySubjectIdOk(matchId), isTrue);
    expect(safetySubjectIdOk('ada@example.test'), isFalse);
  });

  test(
    'demo report stays on the device and drops a poisoned block id',
    () async {
      final gateway = DemoSafetyGateway();
      final stored = await gateway.submit(
        targetType: 'property',
        targetId: 'lst_koramangala',
        reason: 'fake_listing',
        details: 'Photos look copied.',
        blockedUserId: '9876543210',
        alsoBlock: true,
      );
      expect(stored.storedOnServer, isFalse);
      expect(stored.message, contains('moderator queue is not connected'));
      expect(stored.message.contains('@'), isFalse);
      expect(gateway.reports.single.blockedUserId, isNull);
      expect(gateway.reports.single.targetType, 'property');

      expect(
        () => gateway.submit(
          targetType: 'user',
          targetId: 'demo-host-rohan',
          reason: 'spam',
          details: 'ada@example.test',
        ),
        throwsA(isA<SafetyFailure>()),
      );
      expect(gateway.reports, hasLength(1));
    },
  );
}
