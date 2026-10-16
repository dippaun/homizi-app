import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/moderation/domain/moderation_queue.dart';

void main() {
  test('queue rows drop contact fields and free text', () {
    const reportId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1';
    const targetId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2';
    final rows = reportsFromPayload({
      'ok': true,
      'phone': '+910000000071',
      'email': 'ada@example.test',
      'reports': [
        {
          'id': reportId,
          'target_type': 'property',
          'target_id': targetId,
          'reason': 'fake_listing',
          'status': 'open',
          'details': 'call 9876543210',
          'phone': '+910000000071',
          'email': 'ada@example.test',
        },
        {
          'id': 'not-a-uuid',
          'target_type': 'user',
          'target_id': targetId,
          'reason': 'spam',
          'status': 'open',
        },
      ],
    });
    expect(rows, hasLength(1));
    expect(rows.single.id, reportId);
    expect(rows.single.canHideListing, isTrue);
    expect(rows.single.canSuspendUser, isFalse);
    final rendered = '${rows.single.reason} ${rows.single.status}';
    expect(rendered, isNot(contains('@')));
    expect(rendered, isNot(contains('9876543210')));
    expect(moderationErrorMessage('not_staff'), 'You are not a staff account.');
  });
}
